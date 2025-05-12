// DocParser.swift
import Foundation
import Zip
import SWXMLHash
import UIKit
import CoreText

// MARK: - Error Handling (错误处理枚举)
enum DocParserError: Error {
    case unzipFailed(Error)                 // 解压缩DOCX文件失败
    case fileNotFound(String)               // 指定文件未找到 (例如 document.xml)
    case xmlParsingFailed(Error)            // XML解析失败
    case relationshipParsingFailed(String)  // 关系文件解析失败
    case unsupportedFormat(String)          // 不支持的格式
    case resourceLoadFailed(String)         // 资源加载失败 (例如图片)
    case pdfGenerationFailed(String)        // PDF生成失败
    case pdfSavingFailed(Error)             // PDF保存失败
}

// MARK: - Constants and Helpers (常量和辅助结构)
struct DocxConstants {
    // OOXML 单位: English Metric Unit (EMU)
    static let emuPerPoint: CGFloat = 12700.0     // 1 磅 (point) = 12700 EMU
    // 默认字体设置
    static let defaultFontSize: CGFloat = 12.0    // 默认字体大小（磅）
    static let defaultFontName: String = "Times New Roman" // 常见的默认字体 (如果文档中未指定)

    // PDF 生成常量 (用于自定义的 generatePDFWithCustomLayout 方法)
    static let defaultPDFPageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // 默认PDF页面尺寸 (US Letter: 8.5x11 inches, 约等于 612x792 磅)
    static let defaultPDFMargins = UIEdgeInsets(top: 40, left: 40, bottom: 40, right: 40) // PDF页边距 (单位：磅)
    static let pdfLineSpacingAfterVisibleText: CGFloat = 0 // 可见文本内容块之后的额外行间距 (设为0以实现紧凑布局)
    static let pdfImageBottomPadding: CGFloat = 10        // 图片绘制完成后的底部间距
}

// XMLIndexer 扩展，用于安全获取属性值
extension XMLIndexer {
    func attributeValue(by name: String) -> String? {
        return self.element?.attribute(by: name)?.text
    }
}

// MARK: - DocParser Class (DocParser 类，负责解析DOCX文件)
class DocParser {
    typealias XMLNode = XMLIndexer         // XML节点的类型别名
    typealias Attributes = [NSAttributedString.Key: Any] // NSAttributedString属性字典的类型别名
    
    private var relationships: [String: String] = [:] // 存储关系ID到目标路径的映射 (例如 rId1 -> media/image1.png)
    private var mediaBaseURL: URL?                    // 解压后 'word' 目录的URL，用于构建媒体文件的完整路径
    private let styleParser = StyleParser()           // << 集成的样式解析器实例 >>
    private var themeManager: ThemeManager?           // << 新增ThemeManager实例 >>
    
    // MARK: - Public Interface (公共接口)
    /**
     * 解析指定的 DOCX 文件URL，返回一个 NSAttributedString。
     * - Parameter fileURL: DOCX 文件的本地 URL。
     * - Throws: DocParserError 如果解析过程中发生任何错误。
     * - Returns: 表示文档内容的 NSAttributedString。
     */
    func parseFile(fileURL: URL) throws -> NSAttributedString {
        // 1. 解压缩 DOCX 文件 (DOCX 本质上是一个 ZIP 压缩包)
        let unzipDirectory: URL
        do {
            unzipDirectory = try Zip.quickUnzipFile(fileURL) // 使用 Zip Pod 解压
            // print("DOCX解压到: \(unzipDirectory.path)")
        } catch {
            // print("解压DOCX文件错误: \(error)")
            throw DocParserError.unzipFailed(error)
        }
        
        // 设置媒体文件的基础URL (通常是 word/media/ 目录，但关系路径会包含 "media/")
        self.mediaBaseURL = unzipDirectory.appendingPathComponent("word", isDirectory: true)
        
        // 初始化并解析主题文件（注意：要放在解析 styles.xml 或 document.xml 之前，因为他们有可能使用主题）
        self.themeManager = ThemeManager()
        let themeFileURL = unzipDirectory.appendingPathComponent("word/theme/theme1.xml")
        if FileManager.default.fileExists(atPath: themeFileURL.path) {
            do {
                try self.themeManager?.parseTheme(themeFileURL: themeFileURL)
                // print("DocParser: 主题文件解析成功。")
            } catch {
                print("DocParser: 解析主题文件失败: \(error)。将继续而不使用自定义主题颜色。")
                //可以选择抛出错误，或者允许在没有主题的情况下继续
            }
        } else {
            print("DocParser: 主题文件 'word/theme/theme1.xml' 未找到。")
        }
        
        // 2. 解析关系文件 (word/_rels/document.xml.rels)
        // 这个文件定义了主文档中引用的外部资源（如图片、超链接）的ID和实际路径。
        let relsURL = unzipDirectory.appendingPathComponent("word/_rels/document.xml.rels")
        if FileManager.default.fileExists(atPath: relsURL.path) {
            try parseRelationships(relsFileURL: relsURL)
            // print("已解析 \(relationships.count) 个关系。")
        } else {
            print("DocParser: 警告 - 关系文件 'word/_rels/document.xml.rels' 未找到。")
        }
        
        // << 新增: 解析 styles.xml >>
        let stylesURL = unzipDirectory.appendingPathComponent("word/styles.xml")
        // StyleParser 内部会处理文件未找到的情况，允许程序继续执行但没有文档样式
        try styleParser.parseStyles(stylesFileURL: stylesURL)
        
        // 3. 解析主文档 (word/document.xml)
        // 这是包含实际文本内容和结构的核心XML文件。
        let mainDocumentURL = unzipDirectory.appendingPathComponent("word/document.xml")
        guard FileManager.default.fileExists(atPath: mainDocumentURL.path) else {
            throw DocParserError.fileNotFound("word/document.xml")
        }
        // print("正在解析主文档: \(mainDocumentURL.path)")
        
        let xmlString = try String(contentsOf: mainDocumentURL, encoding: .utf8)
        let xml = XMLHash.parse(xmlString) // 使用 SWXMLHash Pod 解析 XML
        
        // 4. 将 XML 结构处理为 NSAttributedString, 从 <w:body> 元素开始
        let attributedString = try processBody(xml: xml["w:document"]["w:body"])
        
        // 5. 清理临时解压目录 (可选)
        // try? FileManager.default.removeItem(at: unzipDirectory)
        
        return attributedString
    }
    
    // 解析关系文件 (私有方法)
    private func parseRelationships(relsFileURL: URL) throws {
        relationships = [:] // 重置/初始化关系字典
        do {
            let xmlString = try String(contentsOf: relsFileURL, encoding: .utf8)
            let xml = XMLHash.parse(xmlString)
            // 遍历 <Relationships> 下的每一个 <Relationship> 元素
            for element in xml["Relationships"]["Relationship"].all {
                if let id = element.attributeValue(by: "Id"),       // 获取 Id 属性 (例如 "rId1")
                   let target = element.attributeValue(by: "Target") { // 获取 Target 属性 (例如 "media/image1.png")
                    relationships[id] = target // 存储 ID 和 Target 的映射
                }
            }
        } catch {
            // print("解析关系文件错误: \(error)")
            throw DocParserError.relationshipParsingFailed(error.localizedDescription)
        }
    }
    
    // 处理 <w:body> 元素及其子元素 (段落 <w:p>, 表格 <w:tbl> 等)
    private func processBody(xml: XMLNode) throws -> NSAttributedString {
        let finalAttributedString = NSMutableAttributedString()
        
        // 遍历 w:body 下的所有直接子元素
        for element in xml.children {
            if element.element?.name == "w:p" { // 段落 (Paragraph)
                let paragraphString = try processParagraph(paragraphXML: element)
                finalAttributedString.append(paragraphString)
                // DOCX的<w:p>本身代表块级结构，在其后追加换行符以在NSAttributedString中分隔段落
                finalAttributedString.append(NSAttributedString(string: "\n"))
            } else if element.element?.name == "w:tbl" { // 表格 (Table)
                let tableString = try processTable(tableXML: element) // 表格内容转为带制表符和换行符的文本
                finalAttributedString.append(tableString)
                finalAttributedString.append(NSAttributedString(string: "\n")) // 表格后也添加换行符
            } else if element.element?.name == "w:sdt" { // 结构化文档标签 (Structured Document Tag / 内容控件)
                let sdtContent = element["w:sdtContent"] // 获取其内容部分
                let contentString = try processBody(xml: sdtContent) // 递归处理SDT的内容
                finalAttributedString.append(contentString)
            }
            // <w:sectPr> (章节属性) 等其他目前不处理的元素会被忽略
        }
        // 清理：如果最终富文本以换行符结尾，移除它，避免文档末尾空行
        if finalAttributedString.length > 0 && finalAttributedString.string.hasSuffix("\n") {
            finalAttributedString.deleteCharacters(in: NSRange(location: finalAttributedString.length - 1, length: 1))
        }
        return finalAttributedString
    }
    
    // MARK: - Paragraph Processing (段落处理)
    // 处理单个 <w:p> 元素
    private func processParagraph(paragraphXML: XMLNode) throws -> NSAttributedString {
        let paragraphAttributedString = NSMutableAttributedString()
        
        // 1. 解析段落属性 (<w:pPr>)，考虑样式继承和直接定义，获取最终生效的段落属性和段内默认运行属性
        //    `effectiveParagraphAttrs` 包含最终的 NSParagraphStyle
        //    `defaultRunAttrsForPara` 是此段落内文本运行的默认起始属性
        let (effectiveParagraphAttrs, defaultRunAttrsForPara) =
        try parseParagraphProperties(fromPPrNode: paragraphXML["w:pPr"])
        
        // 2. 处理列表项前缀 (如果 <w:numPr> 存在)
        var listItemPrefix = "" // 初始化列表项前缀为空字符串
        let numPrIndexer = paragraphXML["w:pPr"]["w:numPr"] // 获取段落属性中的数字编号属性 <w:numPr>
        
        // 检查 <w:numPr> 是否存在。如果存在，表示这可能是一个列表项。
        if numPrIndexer.element != nil {
            // 获取列表级别 <w:ilvl w:val="0">。默认为0级。
            let level = numPrIndexer["w:ilvl"].attributeValue(by: "w:val").flatMap { Int($0) } ?? 0
            
            // TODO: 完整的列表格式化需要解析 numbering.xml 文件以获取真实的编号/项目符号。
            //       目前下面的代码是基于占位符的简化处理。
            
            // 根据列表级别计算缩进字符串。示例：每级缩进4个空格。
            let indent = String(repeating: "    ", count: level)
            
            // 如果未来实现了 numbering.xml 的解析，这里的逻辑需要更新，
            // 以便使用从 numbering.xml 中获取的实际列表标记来替换或增强此处的 indent。
            listItemPrefix = indent // 仅保留缩进
            
            // 如果 listItemPrefix (即缩进字符串) 不为空，则将其添加到段落富文本中。
            if !listItemPrefix.isEmpty {
                // 列表项前缀（现在通常只有缩进）使用段落的默认运行属性
                var prefixActualAttrs = defaultRunAttrsForPara
                if prefixActualAttrs[.font] == nil { // 确保字体属性存在 (以防万一默认属性中没有字体)
                    prefixActualAttrs[.font] = UIFont(name: DocxConstants.defaultFontName, size: DocxConstants.defaultFontSize)
                }
                paragraphAttributedString.append(NSAttributedString(string: listItemPrefix, attributes: prefixActualAttrs))
            }
        }
        // --- 修改结束 ---
        
        // 3. 遍历段落内的子元素（文本运行 <w:r>、超链接 <w:hyperlink>、图片等）
        for node in paragraphXML.children {
            var appendedString: NSAttributedString? = nil // 用于收集当前子元素处理后的富文本
            
            if node.element?.name == "w:r" { // 文本运行 (Run)
                // 传入段落的默认运行属性作为基础，processRun 会再应用运行自身的样式和直接格式
                appendedString = try processRun(runXML: node, baseRunAttributes: defaultRunAttrsForPara)
            } else if node.element?.name == "w:hyperlink" { // 超链接
                appendedString = try processHyperlink(hyperlinkXML: node, baseRunAttributes: defaultRunAttrsForPara)
            } else if node.element?.name == "w:drawing" || node.element?.name == "w:pict" { // 图像 (DrawingML 或 VML)
                appendedString = try processDrawing(drawingXML: node)
            } else if node.element?.name == "w:sym" { // 符号 (Symbol), 如 Wingdings 字体字符
                if let charHex = node.attributeValue(by: "w:char"), // 符号十六进制字符代码 <w:char w:val="F0A7">
                   let fontName = node.attributeValue(by: "w:font") { // 符号字体 <w:font w:val="Wingdings">
                    var symAttrs = defaultRunAttrsForPara // 符号使用段落默认运行属性
                    // 尝试使用符号指定的字体
                    if let symFont = UIFont(name: fontName, size: (symAttrs[.font] as? UIFont)?.pointSize ?? DocxConstants.defaultFontSize) {
                        symAttrs[.font] = symFont
                    }
                    // 将十六进制字符代码转为实际字符
                    if let charCode = UInt32(charHex, radix: 16), let unicodeScalar = UnicodeScalar(charCode) {
                        appendedString = NSAttributedString(string: String(Character(unicodeScalar)), attributes: symAttrs)
                    }
                }
            } else if node.element?.name == "w:tab" { // 显式制表符 <w:tab/>
                appendedString = NSAttributedString(string: "\t", attributes: defaultRunAttrsForPara)
            } else if node.element?.name == "w:br" { // 段内换行符 <w:br/>
                // TODO: 可检查 <w:br w:type="page"/> 实现分页符处理
                appendedString = NSAttributedString(string: "\n", attributes: defaultRunAttrsForPara)
            } else if node.element?.name == "w:smartTag" || node.element?.name == "w:proofErr" { // 智能标签或校对错误标记 (通常包含实际文本)
                // 遍历这些标签内的子元素 (通常是 <w:r>)
                let tempString = NSMutableAttributedString()
                for child in node.children {
                    if child.element?.name == "w:r" {
                        if let runStr = try processRun(runXML: child, baseRunAttributes: defaultRunAttrsForPara) {
                            tempString.append(runStr)
                        }
                    }
                }
                if tempString.length > 0 { appendedString = tempString }
            }
            // <w:pPr> (段落属性) 在开头已处理，此处忽略。
            
            // 如果成功处理了子元素，则追加到段落富文本中
            if let str = appendedString {
                paragraphAttributedString.append(str)
            }
        }
        
        // 4. 将解析出的段落级属性 (对齐、间距、缩进等) 应用于整个段落的富文本。
        if paragraphAttributedString.length > 0 {
            paragraphAttributedString.addAttributes(effectiveParagraphAttrs, range: NSRange(location: 0, length: paragraphAttributedString.length))
        }
        //        print("  String content: [\(paragraphAttributedString.string)]")
        return paragraphAttributedString
    }
    // MARK: - Paragraph Property Parsing (Revised for Styles) (段落属性解析 - 已为样式修改)
    /**
     * 解析 <w:pPr> (段落属性) 元素，综合考虑文档默认样式、命名段落样式及直接定义的属性。
     * - Parameter pPrNode: 指向 <w:pPr> 节点的 XMLIndexer。
     * - Returns: 一个元组，包含最终生效的段落级属性 (paragraphAttributes) 和此段落内文本运行的默认属性 (runAttributes)。
     */
    private func parseParagraphProperties(fromPPrNode pPrNode: XMLNode) throws -> (paragraphAttributes: Attributes, runAttributes: Attributes) {
        var effectiveParagraphAttributes = Attributes()
        var effectiveRunAttributes = Attributes()
        
        // 1. 初始：从 StyleParser 获取文档的默认段落样式属性 (包括其默认运行属性)
        let (docDefaultRunAttrs, docDefaultParaAttrs) = styleParser.getDefaultParagraphStyleAttributes()
        effectiveParagraphAttributes.merge(docDefaultParaAttrs) { _, new in new }
        effectiveRunAttributes.merge(docDefaultRunAttrs) { _, new in new }
        
        // 2. 应用段落命名样式
        if let pStyleId = pPrNode["w:pStyle"].attributeValue(by: "w:val") {
          
            
            let (namedRunStyleAttrs, namedParaStyleAttrs) = styleParser.getResolvedAttributes(forStyleId: pStyleId)
            
//             print("DEBUG DocParser: For Title style '\(pStyleId)' received from StyleParser:")
//             print("  namedRunStyleAttrs: \(namedRunStyleAttrs)")
//             print("  namedParaStyleAttrs: \(namedParaStyleAttrs)")

            
            effectiveParagraphAttributes.merge(namedParaStyleAttrs) { _, new in new }
            effectiveRunAttributes.merge(namedRunStyleAttrs) { _, new in new }
        }
        
        // 3. 基于当前积累的属性创建或修改 NSParagraphStyle 对象
        let paragraphStyleToModify: NSMutableParagraphStyle
        if let existingStyle = effectiveParagraphAttributes[.paragraphStyle] as? NSParagraphStyle {
            paragraphStyleToModify = existingStyle.mutableCopy() as! NSMutableParagraphStyle
        } else {
            paragraphStyleToModify = NSMutableParagraphStyle()
            paragraphStyleToModify.alignment = .natural
            paragraphStyleToModify.lineHeightMultiple = 1.0
        }
        
        // 4. 解析 <w:pPr> 中直接定义的属性，并修改 paragraphStyleToModify 对象
        // ... (对齐、缩进、间距等 NSParagraphStyle 相关属性的解析代码) ...
        // 例如:
        // if let alignVal = pPrNode["w:jc"].attributeValue(by: "w:val") { ... }
        // if let indNode = pPrNode["w:ind"].element { ... }
        // if let spacingNode = pPrNode["w:spacing"].element { ... }
        
        // 将修改后的 NSParagraphStyle 对象存回属性字典
        effectiveParagraphAttributes[.paragraphStyle] = paragraphStyleToModify.copy() // << 确保这行在正确的位置
        
        // 5. 解析 <w:pPr><w:rPr> (段落属性中定义的默认运行属性)，并合并到 effectiveRunAttributes
        if pPrNode["w:rPr"].element != nil {
            let directPPrRunAttrs = parseRunPropertiesFromNode(runPropertyXML: pPrNode["w:rPr"], baseAttributes: effectiveRunAttributes)
            effectiveRunAttributes.merge(directPPrRunAttrs) { _, new in new }
        }
        
        // << 新增：处理段落底纹颜色 >>
          var paragraphBackgroundColor: UIColor?

          // 1. 优先处理 <w:pPr><w:shd> 中直接定义的颜色
          let shdNodeInPPr = pPrNode["w:shd"]
          if shdNodeInPPr.element != nil {
              var shdColorResolved = false
              if let fillHex = shdNodeInPPr.attributeValue(by: "w:fill"), fillHex.lowercased() != "auto" {
                  if let color = UIColor(hex: fillHex) {
                      paragraphBackgroundColor = color
                      shdColorResolved = true
                  }
              }
              if !shdColorResolved, let themeFill = shdNodeInPPr.attributeValue(by: "w:themeFill") {
                  let themeTint = shdNodeInPPr.attributeValue(by: "w:themeFillTint")
                  let themeShade = shdNodeInPPr.attributeValue(by: "w:themeFillShade")
                  // 假设 themeManager 已初始化
                  paragraphBackgroundColor = themeManager?.getColor(forName: themeFill, tint: themeTint, shade: themeShade)
                  shdColorResolved = true
              }
              // 可以添加对 w:val (预定义颜色如 "clear", "solid") 的处理
              if !shdColorResolved && shdNodeInPPr.attributeValue(by: "w:val") == "clear" { // "clear" 意味着无填充
                   paragraphBackgroundColor = nil // 确保是nil
                   shdColorResolved = true
              }
          }

          // 2. 如果 <w:pPr><w:shd> 未定义或未解析成功，则尝试从样式继承的指令中获取
          if paragraphBackgroundColor == nil {
              if let styleBgHex = effectiveParagraphAttributes[ExtendedDocxStyleAttributes.paragraphBackgroundColorHex] as? String,
                 let color = UIColor(hex: styleBgHex) {
                  paragraphBackgroundColor = color
              } else if let styleBgThemeName = effectiveParagraphAttributes[ExtendedDocxStyleAttributes.paragraphBackgroundThemeColorName] as? String {
                  let styleBgThemeTint = effectiveParagraphAttributes[ExtendedDocxStyleAttributes.paragraphBackgroundThemeColorTint] as? String
                  let styleBgThemeShade = effectiveParagraphAttributes[ExtendedDocxStyleAttributes.paragraphBackgroundThemeColorShade] as? String
                  paragraphBackgroundColor = themeManager?.getColor(forName: styleBgThemeName, tint: styleBgThemeTint, shade: styleBgThemeShade)
              }
          }
          
          if let bgColor = paragraphBackgroundColor {
              // 将段落背景色添加到段落级属性中
              // 注意：NSAttributedString.Key.backgroundColor 通常用于文本运行的背景（高亮）
              // 对于整个段落的背景色，在绘制时可能需要特殊处理，或者如果目标是UILabel/UITextView，
              // 它们可能不直接支持整个段落块的独立背景色（不同于文本高亮）。
              // 如果你的目标是生成PDF，你可以在PDF绘制段落时填充一个矩形。
              // 如果是显示在UITextView，可能需要自定义绘制或使用其他技巧。
              // 为了简单起见，我们还是先设置它，看看效果。
              effectiveParagraphAttributes[.backgroundColor] = bgColor
          } else {
              // 如果没有解析到背景色，且 effectiveParagraphAttributes 中可能从样式继承了backgroundColor，则移除它
               effectiveParagraphAttributes.removeValue(forKey: .backgroundColor)
          }
          // << 段落底纹颜色处理结束 >>
        
        // ---- 清理 effectiveParagraphAttributes 中的运行级属性 ----
        // ---- 这是解决问题的关键步骤 ----
        let runAttributeKeys: [NSAttributedString.Key] = [
            .font, .foregroundColor, .backgroundColor, .kern, .ligature,
            .strikethroughStyle, .underlineStyle, .strokeColor, .strokeWidth,
            .shadow, .textEffect, .baselineOffset, .underlineColor,
            .strikethroughColor, .obliqueness, .expansion
            // 添加其他你认为是运行级的键
        ]
        
        // print("DEBUG: parseParagraphProperties - BEFORE cleanup, effectiveParagraphAttributes contains font: \(effectiveParagraphAttributes[.font] != nil), color: \(effectiveParagraphAttributes[.foregroundColor] != nil)")
        
        for key in runAttributeKeys {
            if key == .backgroundColor && effectiveParagraphAttributes[key] != nil {
                       // 如果 .backgroundColor 已经被段落底纹设置了，这里就不应该移除它。
                       // 这是一个潜在的冲突点。如果一个段落有底纹，那么其内部文本运行的高亮（也用.backgroundColor）如何处理？
                       // Word中，文本高亮优先于段落底纹显示。
                       // 如果我们用 .backgroundColor 同时表示两者，那么段落底纹会先生效，
                       // 然后在 processRun 中，如果文本运行有自己的高亮，会用新的 .backgroundColor 覆盖。这似乎是期望的行为。
                       // 所以，如果 .backgroundColor 是被段落底纹设置的，先不要在这一步移除。
                   } else {
                       effectiveParagraphAttributes.removeValue(forKey: key)
                   }
        }
        
        // print("DEBUG: parseParagraphProperties - AFTER cleanup, effectiveParagraphAttributes contains font: \(effectiveParagraphAttributes[.font] != nil), color: \(effectiveParagraphAttributes[.foregroundColor] != nil)")
        // ---- 清理结束 ----
        
        // 在这里再次打印 effectiveParagraphAttributes，确认它不包含 .font 和 .foregroundColor
        // print("DEBUG: parseParagraphProperties - Returning cleaned effectiveParagraphAttributes: \(effectiveParagraphAttributes)")
        
        return (effectiveParagraphAttributes, effectiveRunAttributes)
    }
    
    
    // MARK: - Run Processing (Handles styles and direct formatting) (文本运行处理 - 处理样式和直接格式化)
    /**
     * 处理 <w:r> (文本运行) 元素。
     * - Parameter runXML: 指向 <w:r> 节点的 XMLIndexer。
     * - Parameter baseRunAttributes: 从包含此运行的段落继承来的默认运行属性。
     * - Returns: 表示此文本运行的 NSAttributedString，或nil（如果运行内容为空）。
     */
    private func processRun(runXML: XMLNode, baseRunAttributes: Attributes) throws -> NSAttributedString? {
        let runAttributedString = NSMutableAttributedString()
        var currentEffectiveRunAttributes = baseRunAttributes // 运行属性从段落默认开始
        
        // 1. 应用运行命名样式 (字符样式) (如果 <w:rStyle w:val="StyleID"/> 存在于 <w:rPr> 中)
        //    字符样式会覆盖从段落继承的默认运行属性。
        if let rStyleId = runXML["w:rPr"]["w:rStyle"].attributeValue(by: "w:val") {
            let (charStyleRunAttrs, _) = styleParser.getResolvedAttributes(forStyleId: rStyleId) // 字符样式只关心运行属性
            currentEffectiveRunAttributes.merge(charStyleRunAttrs) { _, new in new } // 字符样式属性优先
        }
        
        // 2. 应用 <w:rPr> 中直接定义的运行属性。
        //    这些直接属性会覆盖从字符样式或段落继承来的属性。
        //    `parseRunPropertiesFromNode` 会基于 `currentEffectiveRunAttributes` 并应用 <w:rPr> 中的直接定义。
        let finalRunAttributes = parseRunPropertiesFromNode(runPropertyXML: runXML["w:rPr"], baseAttributes: currentEffectiveRunAttributes)
        
        // 3. 处理运行内的子元素 (如 <w:t>, <w:tab>, <w:br>, <w:drawing>)
        for node in runXML.children {
            if node.element?.name == "w:t" { // 文本内容
                runAttributedString.append(NSAttributedString(string: node.element?.text ?? "", attributes: finalRunAttributes))
            } else if node.element?.name == "w:tab" { // 制表符
                runAttributedString.append(NSAttributedString(string: "\t", attributes: finalRunAttributes))
            } else if node.element?.name == "w:br" { // 换行符
                runAttributedString.append(NSAttributedString(string: "\n", attributes: finalRunAttributes))
            } else if node.element?.name == "w:drawing" || node.element?.name == "w:pict" { // 内嵌图像
                if let imageString = try processDrawing(drawingXML: node) {
                    runAttributedString.append(imageString)
                }
            } else if node.element?.name == "w:instrText" { // 域代码文本
                runAttributedString.append(NSAttributedString(string: node.element?.text ?? "[域代码]", attributes: finalRunAttributes))
            } else if node.element?.name == "w:noBreakHyphen" { // 不间断连字符
                runAttributedString.append(NSAttributedString(string: "\u{2011}", attributes: finalRunAttributes))
            }
        }
        return runAttributedString.length > 0 ? runAttributedString : nil
    }
    
    // MARK: - Run Property Parsing (for direct formatting, builds on base) (运行属性解析 - 用于直接格式化，基于基础属性构建)
    /**
     * 从 <w:rPr> XML节点解析直接定义的运行属性，并与传入的基础属性合并。
     * - Parameter runPropertyXML: 指向 <w:rPr> 节点的 XMLIndexer。 如果文本运行没有 <w:rPr>，它将是一个无效的 XMLIndexer (其 .element 会是 nil)。
     * - Parameter baseAttributes: 作为基础的运行属性字典 (可能来自段落默认或字符样式)。
     * - Returns: 包含最终生效的运行属性的字典。
     */
    private func parseRunPropertiesFromNode(runPropertyXML: XMLNode, baseAttributes: Attributes) -> Attributes {
        var attributes = baseAttributes // 从基础属性开始，后续解析的直接格式会覆盖这些基础属性
        
        // 从基础属性中提取初始值或设置全局默认值，以便后续的直接格式化可以覆盖它们
        var currentFont = baseAttributes[.font] as? UIFont // 尝试获取基础字体
        var fontSize = currentFont?.pointSize ?? DocxConstants.defaultFontSize // 字体大小，若无基础则用默认
        var fontNameFromDocx: String? = currentFont?.fontName // 字体名称，若无基础则为nil (后续会用默认字体名)
        
        // 初始的粗体/斜体状态从基础字体推断 (如果基础字体存在且带有这些特性)
        var isBold = currentFont?.fontDescriptor.symbolicTraits.contains(.traitBold) ?? false
        var isItalic = currentFont?.fontDescriptor.symbolicTraits.contains(.traitItalic) ?? false
        
        // 初始的下划线/删除线状态从基础属性字典中推断
        var isUnderline = (baseAttributes[.underlineStyle] as? NSNumber)?.intValue == NSUnderlineStyle.single.rawValue
        var isStrikethrough = (baseAttributes[.strikethroughStyle] as? NSNumber)?.intValue == NSUnderlineStyle.single.rawValue
        
        // 初始文本颜色从基础属性推断，如果基础属性中没有颜色，则默认为黑色
        // 默认前景色：首先尝试从基础属性获取，然后是文档默认，最后是纯黑
        var foregroundColor = baseAttributes[.foregroundColor] as? UIColor
        if foregroundColor == nil { // 如果基础属性没有颜色
               // 尝试从样式解析器获取“文档默认字符样式”的颜色（可能已受主题影响）
               // 注意：StyleParser现在不直接解析主题颜色，所以这一步可能不会得到主题色
               // 我们依赖下面对 <w:color> 的显式处理
               foregroundColor = styleParser.getDefaultCharacterStyleAttributes()[.foregroundColor] as? UIColor
          }
          if foregroundColor == nil { // 如果还是没有，尝试主题管理器的默认文本颜色
              foregroundColor = themeManager?.getDefaultTextColor() ?? UIColor.black
          }
        // 背景高亮色，可能为nil
        var highlightColor = baseAttributes[.backgroundColor] as? UIColor
        
        // 垂直对齐状态 (0: 基线, 1: 上标, 2: 下标)
        var verticalAlign: Int = 0
        // 尝试从基础属性的基线偏移推断初始垂直对齐状态
        if let baselineOffset = baseAttributes[.baselineOffset] as? CGFloat {
            // 这个推断比较粗略，基线偏移也可能用于其他精细调整
            if baselineOffset > 0.1 * fontSize { verticalAlign = 1 } // 显著正偏移视为上标
            else if baselineOffset < -0.1 * fontSize { verticalAlign = 2 } // 显著负偏移视为下标
        }
        
        // --- 仅当 runPropertyXML (<w:rPr>) 实际存在时，才解析其中的直接覆盖属性 ---
        if runPropertyXML.element != nil { // 检查 <w:rPr> 节点是否真的存在内容
            // 字体大小 (<w:sz> 定义西文字体大小, <w:szCs> 定义复杂文种/亚洲字体大小)
            // XML中 w:val 的单位是半磅 (half-points)
            if let szStr = runPropertyXML["w:sz"].attributeValue(by: "w:val") ?? runPropertyXML["w:szCs"].attributeValue(by: "w:val"),
               let sizeValHalfPoints = Double(szStr) {
                fontSize = CGFloat(sizeValHalfPoints) / 2.0 // 转换为磅 (points)
            }
            
            // 字体名称 (<w:rFonts>)
            let rFontsNode = runPropertyXML["w:rFonts"]
            if rFontsNode.element != nil {
                // 按照 Word 的优先级尝试获取字体名称: ascii (标准西文), hAnsi (高ANSI/扩展西文), eastAsia (东亚文字), cs (复杂文种)
                // 如果 <w:rFonts> 中指定了任何一个，则使用它来覆盖从 baseAttributes 继承的 fontNameFromDocx
                fontNameFromDocx = rFontsNode.attributeValue(by: "w:ascii") ??
                rFontsNode.attributeValue(by: "w:hAnsi") ??
                rFontsNode.attributeValue(by: "w:eastAsia") ??
                rFontsNode.attributeValue(by: "w:cs") ?? fontNameFromDocx // 如果都没指定，保持原来的值
            }
            
            // 粗体 (<w:b> 或 <w:bCs> 为复杂文种字符设置粗体)
            // DOCX中布尔型属性的规则:
            // 1. 元素存在，无 w:val 属性 (如 <w:b/>): 效果为 true。
            // 2. 元素存在，w:val="true" 或 w:val="1": 效果为 true。
            // 3. 元素存在，w:val="false" 或 w:val="0": 效果为 false。
            // 4. 元素不存在: 效果继承自样式或默认为 false。
            // 下面的逻辑实现了这个规则：如果元素存在，且 w:val 不是 "0" 或 "false" (包括 w:val 不存在的情况)，则为 true。
            if runPropertyXML["w:b"].element != nil { // 优先检查 <w:b>
                let val = runPropertyXML["w:b"].attributeValue(by: "w:val")
                isBold = (val == nil || (val != "0" && val != "false")) // 更新 isBold 状态
            } else if runPropertyXML["w:bCs"].element != nil { // 其次检查 <w:bCs>
                let val = runPropertyXML["w:bCs"].attributeValue(by: "w:val")
                isBold = (val == nil || (val != "0" && val != "false")) // 更新 isBold 状态
            }
            // 如果 <w:rPr> 中没有 <w:b> 或 <w:bCs> 标签，isBold 将保持其从 baseAttributes 继承的初始值。
            
            // 斜体 (<w:i> 或 <w:iCs> 为复杂文种字符设置斜体)
            // 逻辑同粗体
            if runPropertyXML["w:i"].element != nil {
                let val = runPropertyXML["w:i"].attributeValue(by: "w:val")
                isItalic = (val == nil || (val != "0" && val != "false"))
            } else if runPropertyXML["w:iCs"].element != nil {
                let val = runPropertyXML["w:iCs"].attributeValue(by: "w:val")
                isItalic = (val == nil || (val != "0" && val != "false"))
            }
            
            // 下划线 (<w:u>)
            if let uNode = runPropertyXML["w:u"].element { // 检查 <w:u> 元素是否存在
                let uVal = uNode.attribute(by: "w:val")?.text.lowercased()
                // 如果 <w:u> 存在:
                // - 若 w:val="none" (或 "0", 虽然不规范但兼容一下)，则无下划线。
                // - 若 w:val 不存在 (即 <w:u/>)，或 w:val 是其他值 (如 "single", "double" 等)，则有下划线。
                isUnderline = !(uVal == "none" || uVal == "0")
                // TODO: 当前仅支持简单下划线 (NSUnderlineStyle.single)。
                //       未来可以解析 uVal 的具体值 (e.g., "double", "dotted") 来实现更丰富的下划线样式。
            }
            
            // 删除线 (<w:strike> 单删除线, <w:dstrike> 双删除线)
            // 逻辑同粗体/斜体
            if runPropertyXML["w:strike"].element != nil { // 检查单删除线
                let val = runPropertyXML["w:strike"].attributeValue(by: "w:val")
                isStrikethrough = (val == nil || (val != "0" && val != "false"))
            } else if runPropertyXML["w:dstrike"].element != nil { // 检查双删除线 (我们也视作删除线)
                let val = runPropertyXML["w:dstrike"].attributeValue(by: "w:val")
                isStrikethrough = (val == nil || (val != "0" && val != "false"))
            }
            
            // 文本颜色 (<w:color>)
//            // w:val 可以是 "auto", RRGGBB 十六进制值, 或涉及主题颜色 (w:themeColor)。
//            if let colorNode = runPropertyXML["w:color"].element, // 确保 <w:color> 节点存在
//               let colorVal = colorNode.attribute(by: "w:val")?.text { // 获取 w:val 的值
//                
//                if colorVal.lowercased() == "auto" {
//                    // "auto" 颜色通常表示继承自更高层级样式或文档的默认文本颜色 (一般是黑色)。
//                    // 这里尝试从 StyleParser 获取文档默认字符样式的颜色，若无，则默认为黑色。
//                    foregroundColor = styleParser.getDefaultCharacterStyleAttributes()[.foregroundColor] as? UIColor ?? UIColor.black
//                } else if colorNode.attribute(by: "w:themeColor")?.text != nil {
//                    // TODO: 主题颜色处理。这需要解析 themeN.xml 文件和颜色变换 (如 w:themeTint, w:themeShade)。
//                    // 暂时的处理：如果指定了主题颜色但当前不支持解析，foregroundColor 将保持从 baseAttributes 继承的值。
//                    // print("DocParser: 主题颜色 (\(colorVal), theme: \(themeColorName!)) 暂未完全支持，颜色可能不准确。")
//                } else if let color = UIColor(hex: colorVal) { // 尝试将 w:val 解析为十六进制颜色
//                    foregroundColor = color // 如果解析成功，则更新文本颜色
//                }
//                // 如果 w:val 既不是 "auto"，也不是有效十六进制，且不是（当前支持的）主题颜色，
//                // foregroundColor 将保持其从 baseAttributes 继承的初始值。
//            }
            
            if let colorNode = runPropertyXML["w:color"].element { // 确保 <w:color> 节点存在
                       var colorResolved = false
                       // 1. 最高优先级：直接定义的十六进制颜色 <w:color w:val="RRGGBB"/>
                       if let colorValHex = colorNode.attribute(by: "w:val")?.text, colorValHex.lowercased() != "auto" {
                           if let color = UIColor(hex: colorValHex) {
                               foregroundColor = color
                               colorResolved = true
                           }
                       }

                       // 2. 次高优先级：主题颜色 <w:color w:themeColor="accent1" w:themeTint="BF"/>
                       if !colorResolved, let themeColorName = colorNode.attribute(by: "w:themeColor")?.text {
                           let themeTint = colorNode.attribute(by: "w:themeTint")?.text
                           let themeShade = colorNode.attribute(by: "w:themeShade")?.text
                           
                           if let themeColor = themeManager?.getColor(forName: themeColorName, tint: themeTint, shade: themeShade) {
                               foregroundColor = themeColor
                               colorResolved = true
                           } else {
                               // print("DocParser: 无法从主题解析颜色: \(themeColorName), tint: \(themeTint ?? "nil"), shade: \(themeShade ?? "nil")")
                               // 如果主题颜色解析失败，foregroundColor 会保持之前的值（可能来自 baseAttributes 或默认的黑色）
                           }
                       }
                       
                       // 3. "auto" 颜色 或 未指定颜色但<w:color>存在 (通常意味着使用默认)
                       if !colorResolved && (colorNode.attribute(by: "w:val")?.text.lowercased() == "auto" || (!colorResolved && colorNode.allAttributes.isEmpty && colorNode.attribute(by: "w:themeColor") == nil) ) {
                           // "auto" 通常意味着继承或使用文档默认文本颜色（可能是主题的 dk1 或 tx1）
                           foregroundColor = themeManager?.getDefaultTextColor() ?? UIColor.black
                           colorResolved = true
                       }
                       // 如果 <w:color> 节点存在，但无法解析出任何有效颜色（例如无效的 themeColorName），
                       // foregroundColor 将保持其从 baseAttributes 继承的或更早设置的默认值。
                   }
                   // 如果 <w:rPr> 中没有 <w:color> 标签，foregroundColor 将保持其从 baseAttributes 或上面设置的初始默认值继承。

            
            
            
            // 高亮颜色 (<w:highlight>)
            // w:val 是预定义的颜色名称字符串，如 "yellow", "green" 等。
            if let highlightVal = runPropertyXML["w:highlight"].attributeValue(by: "w:val") {
                if highlightVal.lowercased() == "none" { // "none" 表示移除高亮
                    highlightColor = nil
                } else {
                    // mapHighlightColor 方法将 Word 的高亮颜色名映射到 UIColor
                    highlightColor = mapHighlightColor(highlightVal) ?? highlightColor // 如果映射失败，保持原高亮色
                }
            }
            
            // 垂直对齐 (上标/下标) (<w:vertAlign>)
            // w:val 可以是 "superscript", "subscript", 或 "baseline" (默认)。
            if let vertAlignVal = runPropertyXML["w:vertAlign"].attributeValue(by: "w:val") {
                switch vertAlignVal.lowercased() {
                case "superscript": verticalAlign = 1 // 标记为上标
                case "subscript": verticalAlign = 2   // 标记为下标
                default: verticalAlign = 0           // "baseline" 或其他未知值，视为基线对齐
                }
            }
        } // 结束对 <w:rPr> 内部属性的解析
        if attributes[.foregroundColor] == nil && // 当前 attributes 中还没有前景颜色
              runPropertyXML["w:color"].element == nil // 并且rPr中也没有<w:color>元素
           {
               if let styleThemeColorName = baseAttributes[ExtendedDocxStyleAttributes.themeColorName] as? String {
                   let styleThemeTint = baseAttributes[ExtendedDocxStyleAttributes.themeColorTint] as? String
                   let styleThemeShade = baseAttributes[ExtendedDocxStyleAttributes.themeColorShade] as? String
                   if let themeColorFromStyle = themeManager?.getColor(forName: styleThemeColorName, tint: styleThemeTint, shade: styleThemeShade) {
                       foregroundColor = themeColorFromStyle
                   }
               } else if let styleHexColor = baseAttributes[ExtendedDocxStyleAttributes.foregroundColorHex] as? String,
                         let color = UIColor(hex: styleHexColor) {
                   foregroundColor = color
               }
           }
        
        
        // -- 根据解析到的状态 (isBold, isItalic, fontNameFromDocx, fontSize 等) 构建最终字体 --
        var traits: UIFontDescriptor.SymbolicTraits = [] // 用于存储字体特性（粗体、斜体）
        if isBold { traits.insert(.traitBold) }
        if isItalic { traits.insert(.traitItalic) }
        
        var finalFont: UIFont?
        // 优先使用从 DOCX 解析的字体名，如果解析不到或为空，则使用全局默认字体名
        let effectiveFontName = fontNameFromDocx ?? DocxConstants.defaultFontName
        
        // 尝试创建指定名称和大小的基础字体
        if let baseFontAttempt = UIFont(name: effectiveFontName, size: fontSize) {
            if !traits.isEmpty { // 如果需要应用粗体/斜体等特性
                // 尝试从基础字体的描述符获取带有指定特性组合的新字体描述符
                if let fontDescriptorWithTraits = baseFontAttempt.fontDescriptor.withSymbolicTraits(traits) {
                    finalFont = UIFont(descriptor: fontDescriptorWithTraits, size: fontSize) // 使用新描述符创建最终字体
                } else {
                    // 如果无法为该字体应用特性 (罕见情况)，则回退到不带额外特性的基础字体
                    finalFont = baseFontAttempt
                    // print("DocParser: 警告 - 无法为字体 '\(effectiveFontName)' 应用特性: \(traits)。")
                }
            } else { // 如果不需要应用额外特性 (traits 为空)
                finalFont = baseFontAttempt // 直接使用基础字体
            }
        } else { // 如果无法创建指定名称的字体 (例如，字体未安装在系统中)
            // print("DocParser: 警告 - 字体 '\(effectiveFontName)' 未找到或无法加载。将使用系统默认字体。")
            // 回退到系统默认字体，并尝试应用所需的特性
            let systemFont = UIFont.systemFont(ofSize: fontSize)
            if !traits.isEmpty, let fontDescriptorWithTraits = systemFont.fontDescriptor.withSymbolicTraits(traits) {
                finalFont = UIFont(descriptor: fontDescriptorWithTraits, size: fontSize)
            } else { // 如果连系统字体都无法应用特性 (极罕见)，则使用原始系统字体
                finalFont = systemFont
            }
        }
        
        // -- 将最终计算出的属性应用到 NSAttributedString 的属性字典中 --
        if let font = finalFont {
            attributes[.font] = font // 应用最终字体
        } else {
            // 理论上 finalFont 总应该有一个值（至少是系统字体）。
            // 作为最后的保险，如果 finalFont 意外为 nil，则设置一个全局默认字体。
            attributes[.font] = UIFont(name: DocxConstants.defaultFontName, size: DocxConstants.defaultFontSize) ?? UIFont.systemFont(ofSize: DocxConstants.defaultFontSize)
        }
        
        attributes[.foregroundColor] = foregroundColor // 应用最终文本颜色(可能来自主题)
        
        // 应用下划线样式
        if isUnderline {
            attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
        } else {
            attributes.removeValue(forKey: .underlineStyle) // 如果没有下划线，确保移除此属性，以防继承
        }
        
        // 应用删除线样式
        if isStrikethrough {
            attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
        } else {
            attributes.removeValue(forKey: .strikethroughStyle) // 如果没有删除线，确保移除
        }
        
        // 应用背景高亮颜色
        if let bgColor = highlightColor {
            attributes[.backgroundColor] = bgColor
        } else {
            attributes.removeValue(forKey: .backgroundColor) // 如果没有背景高亮，确保移除
        }
        
        // 处理上标/下标的基线偏移和字体大小调整
        if verticalAlign != 0 { // 如果是上标 (1) 或下标 (2)
            // 获取最终确定的字体（可能已应用粗体/斜体）的磅值大小，用于精确计算偏移量
            let actualFontSizeForOffset = (finalFont ?? UIFont.systemFont(ofSize: fontSize)).pointSize
            
            // 设置基线偏移：上标向上偏移，下标向下偏移。这些比例因子是经验值，可调整。
            attributes[.baselineOffset] = (verticalAlign == 1) ? (actualFontSizeForOffset * 0.35) : -(actualFontSizeForOffset * 0.25) // 下标偏移略微调整
            
            // 为上标/下标调整字体大小（通常缩小到约75%）。重要的是在已应用粗体/斜体等特性的字体基础上缩小。
            if let currentBaseFontForSizing = finalFont { // 使用已确定的 finalFont
                let targetSize = actualFontSizeForOffset * 0.75 // 计算目标缩小后的大小
                // 保持原有的字体特性 (如粗体/斜体) 不变，只改变大小
                // 通过用当前字体的特性重新创建描述符，然后指定新大小
                if let smallerFontDescriptor = currentBaseFontForSizing.fontDescriptor.withSymbolicTraits(currentBaseFontForSizing.fontDescriptor.symbolicTraits) {
                    attributes[.font] = UIFont(descriptor: smallerFontDescriptor, size: targetSize)
                } else { // Fallback，理论上不应发生
                    attributes[.font] = UIFont(name: currentBaseFontForSizing.fontName, size: targetSize) ?? UIFont.systemFont(ofSize: targetSize)
                }
            }
        } else { // 如果不是上标/下标 (verticalAlign == 0)，即为普通基线文本
            attributes.removeValue(forKey: .baselineOffset) // 确保移除基线偏移属性
            
            // 如果当前字体大小因为之前的上标/下标处理而被缩小了，现在需要恢复到正常的 fontSize。
            // 同时要保持原有的粗体/斜体特性。
            if let currentFontInAttrs = attributes[.font] as? UIFont, currentFontInAttrs.pointSize != fontSize {
                // 使用当前字体已有的特性，但将大小恢复到 fontSize
                if let restoredFontDescriptor = currentFontInAttrs.fontDescriptor.withSymbolicTraits(currentFontInAttrs.fontDescriptor.symbolicTraits) {
                    attributes[.font] = UIFont(descriptor: restoredFontDescriptor, size: fontSize)
                } else { // Fallback
                    attributes[.font] = UIFont(name: currentFontInAttrs.fontName, size: fontSize) ?? UIFont.systemFont(ofSize: fontSize)
                }
            }
        }
        return attributes // 返回最终的属性字典
    }
    
    
    // MARK: - Hyperlink Processing (超链接处理)
    private func processHyperlink(hyperlinkXML: XMLNode, baseRunAttributes: Attributes) throws -> NSAttributedString? {
        let hyperlinkContent = NSMutableAttributedString()
        var effectiveRunAttributes = baseRunAttributes // 超链接文本的基础运行属性
        
        // 1. 尝试应用 "Hyperlink" 字符样式
        let (hyperlinkStyleRunAttrs, _) = styleParser.getResolvedAttributes(forStyleId: "Hyperlink")
        effectiveRunAttributes.merge(hyperlinkStyleRunAttrs) { _, new in new }
        
        // 2. 遍历超链接内的文本运行 <w:r>
        for runNode in hyperlinkXML["w:r"].all {
            if let runString = try processRun(runXML: runNode, baseRunAttributes: effectiveRunAttributes) {
                hyperlinkContent.append(runString)
            }
        }
        
        // 3. 如果超链接内容不为空，确保其有标准的链接外观
        if hyperlinkContent.length > 0 {
            var needsDefaultColor = true
            var needsDefaultUnderline = true
            
            hyperlinkContent.enumerateAttributes(in: NSRange(0..<hyperlinkContent.length), options: []) { attrs, _, stop in
                if attrs[.foregroundColor] != nil && (attrs[.foregroundColor] as? UIColor != UIColor.black) {
                    needsDefaultColor = false
                }
                if attrs[.underlineStyle] != nil && (attrs[.underlineStyle] as? NSNumber)?.intValue != 0 {
                    needsDefaultUnderline = false
                }
                if !needsDefaultColor && !needsDefaultUnderline {
                    stop.pointee = true
                }
            }
            
            if needsDefaultColor {
                hyperlinkContent.addAttribute(.foregroundColor, value: UIColor.blue, range: NSRange(0..<hyperlinkContent.length))
            }
            if needsDefaultUnderline {
                hyperlinkContent.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: NSRange(0..<hyperlinkContent.length))
            }
        }
        
        // 4. 应用链接目标URL
        if let relationshipId = hyperlinkXML.attributeValue(by: "r:id"),
           let targetPath = relationships[relationshipId] {
            var linkURL: URL?
            if targetPath.starts(with: "http://") || targetPath.starts(with: "https://") || targetPath.starts(with: "mailto:") {
                linkURL = URL(string: targetPath)
            }
            if let url = linkURL, hyperlinkContent.length > 0 {
                hyperlinkContent.addAttribute(.link, value: url, range: NSRange(location: 0, length: hyperlinkContent.length))
            }
        }
        return hyperlinkContent.length > 0 ? hyperlinkContent : nil
    }
    
    
    // MARK: - Drawing (Image) Processing (图像处理)
    private func processDrawing(drawingXML: XMLNode) throws -> NSAttributedString? {
        var embedId: String?
        var extentX: Double?
        var extentY: Double?
        
        let blipSearch = drawingXML.deepSearch(elements: ["a:blip"])
        if let blipNode = blipSearch.first {
            embedId = blipNode.attributeValue(by: "r:embed")
            var parentAnchorOrInline = blipNode
            var extentNode: XMLNode?
            for _ in 0..<8 {
                if let currentExtent = parentAnchorOrInline["wp:extent"].element != nil ? parentAnchorOrInline["wp:extent"] : (parentAnchorOrInline["a:ext"].element != nil ? parentAnchorOrInline["a:ext"] : nil) {
                    extentNode = currentExtent
                    break
                }
                if parentAnchorOrInline.element?.name == "wp:inline" || parentAnchorOrInline.element?.name == "wp:anchor" || parentAnchorOrInline.element?.name == "pic:spPr" {
                    if let currentExtent = parentAnchorOrInline["wp:extent"].element != nil ? parentAnchorOrInline["wp:extent"] : (parentAnchorOrInline["a:ext"].element != nil ? parentAnchorOrInline["a:ext"] : nil) {
                        extentNode = currentExtent
                        break
                    }
                }
                if let p = parentAnchorOrInline.element?.parent { parentAnchorOrInline = XMLIndexer(p) } else { break }
            }
            if extentNode == nil {
                extentNode = drawingXML.deepSearch(elements: ["wp:extent", "a:ext"]).first
            }
            
            if let ext = extentNode {
                extentX = ext.attributeValue(by: "cx").flatMap { Double($0) }
                extentY = ext.attributeValue(by: "cy").flatMap { Double($0) }
            }
        }
        else if let imageDataNode = drawingXML.deepSearch(elements: ["v:imagedata"]).first {
            embedId = imageDataNode.attributeValue(by: "r:id")
            if let shapeNode = drawingXML.deepSearch(elements: ["v:shape"]).first,
               let styleString = shapeNode.attributeValue(by: "style") {
                if let widthInPoints = styleString.extractValue(forKey: "width", unit: "pt") {
                    extentX = Double(widthInPoints * DocxConstants.emuPerPoint)
                }
                if let heightInPoints = styleString.extractValue(forKey: "height", unit: "pt") {
                    extentY = Double(heightInPoints * DocxConstants.emuPerPoint)
                }
            }
        }
        
        guard let id = embedId,
              let imageRelativePath = relationships[id],
              let base = mediaBaseURL else {
            return NSAttributedString(string: "[图像: 引用信息缺失]")
        }
        
        let imageURL = base.appendingPathComponent(imageRelativePath)
        
        guard FileManager.default.fileExists(atPath: imageURL.path) else {
            return NSAttributedString(string: "[图像: 文件 '\(imageRelativePath)' 未找到]")
        }
        
        if let image = UIImage(contentsOfFile: imageURL.path) {
            let textAttachment = NSTextAttachment()
            textAttachment.image = image
            
            if let cx = extentX, let cy = extentY, cx > 0, cy > 0 {
                let widthInPoints = CGFloat(cx / DocxConstants.emuPerPoint)
                let heightInPoints = CGFloat(cy / DocxConstants.emuPerPoint)
                textAttachment.bounds = CGRect(x: 0, y: 0, width: widthInPoints, height: heightInPoints)
            }
            return NSAttributedString(attachment: textAttachment)
        } else {
            return NSAttributedString(string: "[图像: 加载失败 '\(imageRelativePath)']")
        }
    }
    
    // MARK: - Table Processing & Helpers (表格处理及辅助函数)
    /*
     如果表格单元格背景色 (<w:shd w:fill="RRGGBB" w:themeFill="accent1"/>) 或段落底纹也需要支持主题色，那么在 processTable (针对单元格的 tcPr) 或 parseParagraphProperties (针对段落的 pPr) 中解析 <w:shd> 时，也需要类似 parseRunPropertiesFromNode 中处理 <w:color> 的逻辑，并使用 themeManager
     */
    private func processTable(tableXML: XMLNode) throws -> NSAttributedString {
        var columnWidthsTwips: [CGFloat] = []
        var defaultTableBorders = TableBorders()
        var tableIndentationTwips: CGFloat = 0
        var hasExplicitTableBorders = false
        
        if let tblGridElement = tableXML["w:tblGrid"].element {
            for childContent in tblGridElement.children {
                if let gridColElement = childContent as? XMLElement, gridColElement.name == "w:gridCol" {
                    let gridColIndexer = XMLIndexer(gridColElement)
                    if let wStr = gridColIndexer.attributeValue(by: "w:w"), let w = Double(wStr) {
                        columnWidthsTwips.append(CGFloat(w))
                    } else {
                        columnWidthsTwips.append(2160)
                    }
                }
            }
        }
        
        if columnWidthsTwips.isEmpty {
            if let firstRowIndexer = tableXML["w:tr"].all.first,
               let firstRowElement = firstRowIndexer.element {
                let cellElements = firstRowElement.children.compactMap { $0 as? XMLElement }.filter { $0.name == "w:tc" }
                if !cellElements.isEmpty {
                    let estimatedColumnCount = cellElements.reduce(0) { count, cellElement in
                        let cellIndexer = XMLIndexer(cellElement)
                        let spanStr = cellIndexer["w:tcPr"]["w:gridSpan"].attributeValue(by: "w:val")
                        return count + (Int(spanStr ?? "1") ?? 1)
                    }
                    if estimatedColumnCount > 0 {
                        let avgWidthTwips = (DocxConstants.defaultPDFPageRect.width * 0.9 * 20.0) / CGFloat(estimatedColumnCount)
                        columnWidthsTwips = Array(repeating: avgWidthTwips, count: estimatedColumnCount)
                    } else {
                        columnWidthsTwips = [DocxConstants.defaultPDFPageRect.width * 0.9 * 20.0]
                    }
                } else {
                    columnWidthsTwips = [DocxConstants.defaultPDFPageRect.width * 0.9 * 20.0]
                }
            } else {
                columnWidthsTwips = [DocxConstants.defaultPDFPageRect.width * 0.9 * 20.0]
            }
        }
        let columnWidthsPoints = columnWidthsTwips.map { $0 / 20.0 }
        
        let tblPrIndexer = tableXML["w:tblPr"]
        if tblPrIndexer.element != nil {
            let tblBordersIndexer = tblPrIndexer["w:tblBorders"]
            if tblBordersIndexer.element != nil {
                hasExplicitTableBorders = true
                defaultTableBorders.top = parseBorderElement(tblBordersIndexer["w:top"])
                defaultTableBorders.left = parseBorderElement(tblBordersIndexer["w:left"])
                defaultTableBorders.bottom = parseBorderElement(tblBordersIndexer["w:bottom"])
                defaultTableBorders.right = parseBorderElement(tblBordersIndexer["w:right"])
                defaultTableBorders.insideHorizontal = parseBorderElement(tblBordersIndexer["w:insideH"])
                defaultTableBorders.insideVertical = parseBorderElement(tblBordersIndexer["w:insideV"])
            }
            
            let tblIndIndexer = tblPrIndexer["w:tblInd"]
            if tblIndIndexer.element != nil,
               let wStr = tblIndIndexer.attributeValue(by: "w:w"), let w = Double(wStr),
               (tblIndIndexer.attributeValue(by: "w:type") == "dxa" || tblIndIndexer.attributeValue(by: "w:type") == nil ) {
                tableIndentationTwips = CGFloat(w)
            }
        }
        if !hasExplicitTableBorders {
            let defaultGridBorder = TableBorderInfo.defaultBorder
            defaultTableBorders.top = defaultGridBorder
            defaultTableBorders.left = defaultGridBorder
            defaultTableBorders.bottom = defaultGridBorder
            defaultTableBorders.right = defaultGridBorder
            defaultTableBorders.insideHorizontal = defaultGridBorder
            defaultTableBorders.insideVertical = defaultGridBorder
        }
        
        var tableRowsData: [TableRowDrawingData] = []
        var vMergeTracker: [Int: TableCellDrawingData] = [:]
        
        for (rowIndex, rowXML) in tableXML["w:tr"].all.enumerated() {
            var cellsDataInCurrentRow: [TableCellDrawingData] = []
            var currentLogicalColumnIndex = 0
            
            let trPrIndexer = rowXML["w:trPr"]
            var rowSpecifiedHeightPoints: CGFloat? = nil
            var isHeaderRow = false
            
            if trPrIndexer.element != nil {
                let trHeightIndexer = trPrIndexer["w:trHeight"]
                if trHeightIndexer.element != nil,
                   let hStr = trHeightIndexer.attributeValue(by: "w:val"), let hValTwips = Double(hStr) {
                    rowSpecifiedHeightPoints = CGFloat(hValTwips) / 20.0
                }
                if trPrIndexer["w:tblHeader"].element != nil {
                    isHeaderRow = true
                }
            }
            
            for (cellXmlIndexInRow, cellXML) in rowXML["w:tc"].all.enumerated() {
                let cellContentAccumulator = NSMutableAttributedString()
                var cellBackgroundColor: UIColor?
                var cellGridSpan = 1
                var cellVMergeStatus: VerticalMergeStatus = .none
                var cellSpecificBorders = defaultTableBorders
                var cellMarginsPoints = UIEdgeInsets.zero
                var hasExplicitCellBorders = false
                
                let tcPrIndexer = cellXML["w:tcPr"]
                if tcPrIndexer.element != nil {
                    if let gridSpanStr = tcPrIndexer["w:gridSpan"].attributeValue(by: "w:val"), let span = Int(gridSpanStr) {
                        cellGridSpan = span
                    }
                    
                    let vMergeIndexer = tcPrIndexer["w:vMerge"]
                    if vMergeIndexer.element != nil {
                        cellVMergeStatus = (vMergeIndexer.attributeValue(by: "w:val") == "restart") ? .restart : .continue
                    } else {
                        if vMergeTracker[currentLogicalColumnIndex] != nil {
                            vMergeTracker.removeValue(forKey: currentLogicalColumnIndex)
                        }
                    }
                    
                    let shdIndexer = tcPrIndexer["w:shd"]
                    if shdIndexer.element != nil {
                        var resolvedCellBackgroundColor: UIColor? = nil
                        // 1. 优先使用 w:fill (直接十六进制)
                        if let fillHex = shdIndexer.attributeValue(by: "w:fill"), fillHex.lowercased() != "auto" {
                            if let color = UIColor(hex: fillHex) {
                                resolvedCellBackgroundColor = color
                            }
                        }
                        // 2. 如果没有直接fill，尝试主题填充 w:themeFill
                        if resolvedCellBackgroundColor == nil, let themeFillName = shdIndexer.attributeValue(by: "w:themeFill") {
                            let themeFillTint = shdIndexer.attributeValue(by: "w:themeFillTint")
                            let themeFillShade = shdIndexer.attributeValue(by: "w:themeFillShade")
                            // 注意：themeFillTtint/Shade 的 w:val 是 0-100000 的整数，需要转换为 ThemeManager.percentageFromHex 能接受的格式
                            // 或者 ThemeManager.percentageFromHex 需要扩展以处理这种整数百分比字符串
                            // 为简单起见，假设 ThemeManager 可以处理这些值或它们是预期的格式
                            resolvedCellBackgroundColor = themeManager?.getColor(forName: themeFillName, tint: themeFillTint, shade: themeFillShade)
                        }
                        // 3. w:val="auto" 或无颜色定义但有<w:shd>，通常表示无填充或继承文档背景
                        //    我们这里如果没有解析到颜色，cellBackgroundColor 就保持为 nil
                        if resolvedCellBackgroundColor != nil {
                             cellBackgroundColor = resolvedCellBackgroundColor
                        }
                    }
                    
                    let tcBordersIndexer = tcPrIndexer["w:tcBorders"]
                    if tcBordersIndexer.element != nil {
                        hasExplicitCellBorders = true
                        if tcBordersIndexer["w:top"].element != nil { cellSpecificBorders.top = parseBorderElement(tcBordersIndexer["w:top"]) }
                        if tcBordersIndexer["w:left"].element != nil { cellSpecificBorders.left = parseBorderElement(tcBordersIndexer["w:left"]) }
                        if tcBordersIndexer["w:bottom"].element != nil { cellSpecificBorders.bottom = parseBorderElement(tcBordersIndexer["w:bottom"]) }
                        if tcBordersIndexer["w:right"].element != nil { cellSpecificBorders.right = parseBorderElement(tcBordersIndexer["w:right"]) }
                    }
                    
                    let tcMarIndexer = tcPrIndexer["w:tcMar"]
                    if tcMarIndexer.element != nil {
                        let twipsPerPointMar: CGFloat = 20.0
                        if let wStr = tcMarIndexer["w:top"].attributeValue(by: "w:w"), let w = Double(wStr) { cellMarginsPoints.top = CGFloat(w) / twipsPerPointMar }
                        if let wStr = tcMarIndexer["w:left"].attributeValue(by: "w:w"), let w = Double(wStr) { cellMarginsPoints.left = CGFloat(w) / twipsPerPointMar }
                        if let wStr = tcMarIndexer["w:bottom"].attributeValue(by: "w:w"), let w = Double(wStr) { cellMarginsPoints.bottom = CGFloat(w) / twipsPerPointMar }
                        if let wStr = tcMarIndexer["w:right"].attributeValue(by: "w:w"), let w = Double(wStr) { cellMarginsPoints.right = CGFloat(w) / twipsPerPointMar }
                    }
                }
                
                if let tcElement = cellXML.element {
                    for contentNode in tcElement.children {
                        if let contentElement = contentNode as? XMLElement {
                            let contentIndexer = XMLIndexer(contentElement)
                            if contentElement.name == "w:p" {
                                let paraString = try processParagraph(paragraphXML: contentIndexer)
                                cellContentAccumulator.append(paraString)
                                if !paraString.string.hasSuffix("\n") && cellContentAccumulator.length > 0 {
                                    cellContentAccumulator.append(NSAttributedString(string: "\n"))
                                }
                            } else if contentElement.name == "w:tbl" {
                                let nestedTableAttrString = try processTable(tableXML: contentIndexer)
                                cellContentAccumulator.append(nestedTableAttrString)
                                if !nestedTableAttrString.string.hasSuffix("\n") && cellContentAccumulator.length > 0 {
                                    cellContentAccumulator.append(NSAttributedString(string: "\n"))
                                }
                            }
                        }
                    }
                }
                if cellContentAccumulator.length > 0 && cellContentAccumulator.string.hasSuffix("\n") {
                    cellContentAccumulator.deleteCharacters(in: NSRange(location: cellContentAccumulator.length - 1, length: 1))
                }
                
                let currentCellData = TableCellDrawingData(
                    content: cellContentAccumulator,
                    borders: cellSpecificBorders,
                    backgroundColor: cellBackgroundColor,
                    gridSpan: cellGridSpan,
                    vMerge: cellVMergeStatus,
                    margins: cellMarginsPoints,
                    originalRowIndex: rowIndex,
                    originalColIndex: currentLogicalColumnIndex
                )
                cellsDataInCurrentRow.append(currentCellData)
                
                if cellVMergeStatus == .restart {
                    for i in 0..<cellGridSpan {
                        vMergeTracker[currentLogicalColumnIndex + i] = currentCellData
                    }
                }
                currentLogicalColumnIndex += cellGridSpan
            }
            tableRowsData.append(TableRowDrawingData(cells: cellsDataInCurrentRow,
                                                     height: 0,
                                                     specifiedHeight: rowSpecifiedHeightPoints,
                                                     isHeaderRow: isHeaderRow))
        }
        
        let finalTableDrawingData = TableDrawingData(
            rows: tableRowsData,
            columnWidthsPoints: columnWidthsPoints,
            defaultCellBorders: defaultTableBorders,
            tableIndentation: tableIndentationTwips / 20.0
        )
        
        let finalAttributedString = NSMutableAttributedString(string: "\u{FFFC}")
        finalAttributedString.addAttribute(DocParser.tableDrawingDataAttributeKey,
                                           value: finalTableDrawingData,
                                           range: NSRange(location: 0, length: finalAttributedString.length))
        return finalAttributedString
    }
    
    private func parseBorderElement(_ borderXMLIndexer: XMLIndexer?) -> TableBorderInfo {
        guard let node = borderXMLIndexer?.element else {
            return .noBorder
        }
        let valAttr = node.attribute(by: "w:val")?.text.lowercased()
        if valAttr == "nil" || valAttr == "none" {
            return .noBorder
        }
        var borderInfo = TableBorderInfo.defaultBorder
        if let styleVal = valAttr {
            switch styleVal {
            case "single": borderInfo.style = .single
            case "double": borderInfo.style = .double
            case "dashed": borderInfo.style = .dashed
            case "dotted": borderInfo.style = .dotted
            default: borderInfo.style = .single
            }
        } else {
            borderInfo.style = .single
        }
        if let szStr = node.attribute(by: "w:sz")?.text, let szEighthsOfPoint = Double(szStr) {
            borderInfo.width = CGFloat(szEighthsOfPoint) / 8.0
        } else {
            if borderInfo.style == .single { borderInfo.width = 0.5 }
            else if borderInfo.style == .double { borderInfo.width = 1.5 }
        }
        if let colorHex = node.attribute(by: "w:color")?.text, colorHex.lowercased() != "auto" {
            if let color = UIColor(hex: colorHex) {
                borderInfo.color = color
            } else {
                borderInfo.color = .black
            }
        } else {
            borderInfo.color = .black
        }
        if let spaceStr = node.attribute(by: "w:space")?.text, let spacePoints = Double(spaceStr) {
            borderInfo.space = CGFloat(spacePoints)
        }
        if borderInfo.width <= 0 {
            return .noBorder
        }
        return borderInfo
    }
    
    // MARK: - Helper Functions (辅助函数)
    private func mapHighlightColor(_ value: String) -> UIColor? {
        switch value.lowercased() {
        case "black": return UIColor(white: 0.3, alpha: 0.4)
        case "blue": return UIColor.blue.withAlphaComponent(0.3)
        case "cyan": return UIColor.cyan.withAlphaComponent(0.3)
        case "green": return UIColor.green.withAlphaComponent(0.3)
        case "magenta": return UIColor.magenta.withAlphaComponent(0.3)
        case "red": return UIColor.red.withAlphaComponent(0.3)
        case "yellow": return UIColor.yellow.withAlphaComponent(0.4)
        case "white": return UIColor(white: 0.95, alpha: 0.5)
        case "darkblue": return UIColor.blue.withAlphaComponent(0.5)
        case "darkcyan": return UIColor.cyan.withAlphaComponent(0.5)
        case "darkgreen": return UIColor.green.withAlphaComponent(0.5)
        case "darkmagenta": return UIColor.magenta.withAlphaComponent(0.5)
        case "darkred": return UIColor.red.withAlphaComponent(0.5)
        case "darkyellow": return UIColor.yellow.withAlphaComponent(0.6)
        case "darkgray": return UIColor.darkGray.withAlphaComponent(0.4)
        case "lightgray": return UIColor.lightGray.withAlphaComponent(0.4)
        default: return nil
        }
    }
    
    // MARK: - PDF Generation (PDF 生成)
    func generatePDFWithCustomLayout(
        attributedString: NSAttributedString, // 这是由 parseFile 返回的完整文档内容
        outputPathURL: URL? = nil
    ) throws -> Data {
        guard attributedString.length > 0 else {
            throw DocParserError.pdfGenerationFailed("输入的 NSAttributedString 为空，无法生成PDF。")
        }
        
        // 页面和边距设置
        let pageRect = DocxConstants.defaultPDFPageRect
        let topMargin = DocxConstants.defaultPDFMargins.top
        let bottomMargin = DocxConstants.defaultPDFMargins.bottom
        let leftMargin = DocxConstants.defaultPDFMargins.left
        let rightMargin = DocxConstants.defaultPDFMargins.right
        
        // 可打印区域的宽度
        let printableWidth = pageRect.width - leftMargin - rightMargin
        
        // PDF 数据缓冲区
        let pdfData = NSMutableData()
        UIGraphicsBeginPDFContextToData(pdfData, pageRect, nil)
        
        // 开始第一页
        UIGraphicsBeginPDFPageWithInfo(pageRect, nil)
        var currentY: CGFloat = topMargin      // 当前绘制操作的起始Y坐标 (通常是行顶)
        var lastDrawnContentHeight: CGFloat = 0 // 最近一次绘制内容（行、图片、表格）的高度
        
        // 辅助函数：开始新的一页PDF
        func startNewPDFPage() {
            UIGraphicsBeginPDFPageWithInfo(pageRect, nil)
            currentY = topMargin
            lastDrawnContentHeight = 0
        }
        
        let fullOriginalString = attributedString.string
        var searchStartIndex = 0
        
        // 按原始段落（由 \n 分隔）迭代
        while searchStartIndex < fullOriginalString.count {
            let remainingStringToSearchIn = String(fullOriginalString.dropFirst(searchStartIndex))
            var paragraphAttributedStringSegment: NSAttributedString
            var nextParagraphStartIndexInFullString: Int
            
            if let newlineRangeInRemaining = remainingStringToSearchIn.range(of: "\n") {
                let length = remainingStringToSearchIn.distance(from: remainingStringToSearchIn.startIndex, to: newlineRangeInRemaining.lowerBound)
                paragraphAttributedStringSegment = attributedString.attributedSubstring(from: NSRange(location: searchStartIndex, length: length))
                nextParagraphStartIndexInFullString = searchStartIndex + length + 1
            } else {
                paragraphAttributedStringSegment = attributedString.attributedSubstring(from: NSRange(location: searchStartIndex, length: fullOriginalString.count - searchStartIndex))
                nextParagraphStartIndexInFullString = fullOriginalString.count
            }
            
            var specialObjectProcessedThisSegment = false
            
            // --- 特殊对象处理：图片和表格 ---
            if paragraphAttributedStringSegment.length == 1 {
                let attrs = paragraphAttributedStringSegment.attributes(at: 0, effectiveRange: nil)
                
                if let attachment = attrs[.attachment] as? NSTextAttachment, var imageToDraw = attachment.image {
                    specialObjectProcessedThisSegment = true
                    let originalImageRef = imageToDraw
                    var imageSize = imageToDraw.size
                    
                    if imageSize.width > printableWidth {
                        let scale = printableWidth / imageSize.width
                        imageSize.width *= scale; imageSize.height *= scale
                    }
                    if currentY + imageSize.height > pageRect.height - bottomMargin {
                        if currentY > topMargin { startNewPDFPage() }
                        if currentY + imageSize.height > pageRect.height - bottomMargin {
                            let scale = max(0.01, (pageRect.height - bottomMargin - currentY) / imageSize.height)
                            imageSize.width *= scale; imageSize.height *= scale
                        }
                    }
                    if imageToDraw.size != imageSize && imageSize.width > 0 && imageSize.height > 0 {
                        UIGraphicsBeginImageContextWithOptions(imageSize, false, 0.0)
                        originalImageRef.draw(in: CGRect(origin: .zero, size: imageSize))
                        imageToDraw = UIGraphicsGetImageFromCurrentImageContext() ?? originalImageRef
                        UIGraphicsEndImageContext()
                    }
                    let imageDrawRect = CGRect(x: leftMargin, y: currentY, width: imageSize.width, height: imageSize.height)
                    imageToDraw.draw(in: imageDrawRect)
                    let totalImageBlockHeight = imageSize.height + DocxConstants.pdfImageBottomPadding
                    currentY += totalImageBlockHeight
                    lastDrawnContentHeight = totalImageBlockHeight
                    
                } else if let tableData = attrs[DocParser.tableDrawingDataAttributeKey] as? DocParser.TableDrawingData {
                    specialObjectProcessedThisSegment = true
                    
                    
                    // **高亮修正点 1: 获取 PDF 上下文并传递给表格绘制逻辑**
                    guard let pdfContext = UIGraphicsGetCurrentContext() else {
                        // print("Error: Could not get PDF context for table drawing.")
                        // 如果无法获取上下文，我们可以尝试跳过这个表格，并增加一些Y值
                        currentY += 50 // 任意增加一点高度
                        lastDrawnContentHeight = 50
                        searchStartIndex = nextParagraphStartIndexInFullString // 移动到下一个段落
                        continue // 跳过当前段落的处理
                    }
                    
                    // **高亮修正点 2: 调用您提供的表格绘制代码**
                    // 这部分代码现在被嵌入到这里。
                    // 它会使用并修改外部的 `currentY` 和调用 `startNewPDFPage()`
                    
                    let tableOriginX = leftMargin + tableData.tableIndentation
                    // var currentTableContentY = currentY // 不再需要这个局部变量，直接使用 currentY
                    let estimatedMinRowHeightPoints: CGFloat = 20 // 表格内部使用的常量
                    
                    // 表格开始前，检查是否需要换页（基于一个估算的最小行高）
                    if currentY + estimatedMinRowHeightPoints > pageRect.height - bottomMargin && currentY > topMargin {
                        startNewPDFPage() // 调用外部的换页函数
                    }
                    // currentY 此时是表格的起始Y坐标
                    
                    let columnWidths = tableData.columnWidthsPoints
                    // var calculatedRowYOrigins: [CGFloat] = [] // 这个变量在您的原始代码中被赋值但未被有效使用
                    var calculatedRowHeights: [CGFloat] = []
                    
                    // 计算所有行的高度 (与您提供的代码一致)
                    for (rowIndex, rowData) in tableData.rows.enumerated() {
                        var maxCellHeightInRowPoints: CGFloat = 0.0
                        if let specifiedH = rowData.specifiedHeight, specifiedH > 0 {
                            maxCellHeightInRowPoints = specifiedH
                        } else {
                            for (cellIndexInRow, cellData) in rowData.cells.enumerated() {
                                if cellData.vMerge == .continue { continue }
                                var currentCellWidthPoints: CGFloat = 0
                                for spanIdx in 0..<cellData.gridSpan {
                                    if (cellData.originalColIndex + spanIdx) < columnWidths.count {
                                        currentCellWidthPoints += columnWidths[cellData.originalColIndex + spanIdx]
                                    }
                                }
                                let contentWidth = max(1, currentCellWidthPoints - cellData.margins.left - cellData.margins.right)
                                let textBoundingRect = cellData.content.boundingRect(
                                    with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
                                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                                    context: nil
                                )
                                var currentCellRequiredHeightPoints = ceil(textBoundingRect.height)
                                currentCellRequiredHeightPoints += (cellData.margins.top + cellData.margins.bottom)
                                maxCellHeightInRowPoints = max(maxCellHeightInRowPoints, currentCellRequiredHeightPoints)
                            }
                            maxCellHeightInRowPoints = max(maxCellHeightInRowPoints, estimatedMinRowHeightPoints)
                        }
                        calculatedRowHeights.append(max(maxCellHeightInRowPoints, estimatedMinRowHeightPoints))
                    }
                    
                    // 记录表格开始时的Y，用于计算表格总高度
                    let tableDrawStartOriginalY = currentY
                    
                    var currentDrawingCellX = tableOriginX // 用于表格内部单元格的X定位
                    for (rowIndex, rowData) in tableData.rows.enumerated() {
                        let currentRowHeightPoints = calculatedRowHeights[rowIndex] // 当前表格行的高度
                        // calculatedRowYOrigins.append(currentY) // 赋值但未使用
                        
                        // 表格行分页检查 (与您提供的代码一致)
                        if currentY + currentRowHeightPoints > pageRect.height - bottomMargin {
                            if currentY > topMargin {
                                startNewPDFPage() // 调用外部的换页函数
                                // currentY 已被 startNewPage 更新为 topMargin
                                // calculatedRowYOrigins[rowIndex] = currentY // 如果需要，更新内部跟踪的Y原点
                            }
                            // 如果换页后仍然无法容纳这一行（行本身超高），则可能需要更复杂的行分割逻辑
                            // 目前假设换页后总能放下，或者这一行会被截断/不完整显示
                            if currentY + currentRowHeightPoints > pageRect.height - bottomMargin && currentY == topMargin {
                                // print("Warning: Table row \(rowIndex) is too high (\(currentRowHeightPoints)pts) for a new page. It might be truncated.")
                                // 在这种情况下，可能选择不绘制这一行，或者只绘制页面能容纳的部分，然后强制新页
                                // 为简单起见，我们继续绘制，它会被截断
                            }
                        }
                        
                        currentDrawingCellX = tableOriginX
                        for (cellIndexInRow, cellData) in rowData.cells.enumerated() {
                            // ... (您提供的单元格宽度、高度、合并、背景、边框、内容绘制逻辑完全保留) ...
                            var cellDrawingWidthPoints: CGFloat = 0
                            for spanIdx in 0..<cellData.gridSpan { if (cellData.originalColIndex + spanIdx) < columnWidths.count { cellDrawingWidthPoints += columnWidths[cellData.originalColIndex + spanIdx] } }
                            if cellDrawingWidthPoints <= 0 { cellDrawingWidthPoints = 50 }
                            var cellDrawingHeightPoints = currentRowHeightPoints
                            if cellData.vMerge == .restart { /* vMerge restart logic */
                                cellDrawingHeightPoints = 0
                                for rIdx in rowIndex..<tableData.rows.count {
                                    let spannedRowData = tableData.rows[rIdx]; var currentLogicalColForSearch = 0; var targetCellInSpannedRow: TableCellDrawingData? = nil
                                    for c_search in spannedRowData.cells { if currentLogicalColForSearch == cellData.originalColIndex { targetCellInSpannedRow = c_search; break }; currentLogicalColForSearch += c_search.gridSpan }
                                    if let actualCellInSpannedRow = targetCellInSpannedRow, (rIdx == rowIndex || actualCellInSpannedRow.vMerge == .continue) { cellDrawingHeightPoints += calculatedRowHeights[rIdx] } else { break }
                                }
                            } else if cellData.vMerge == .continue { /* vMerge continue logic */
                                let cellRectForContinue = CGRect(x: currentDrawingCellX, y: currentY, width: cellDrawingWidthPoints, height: currentRowHeightPoints)
                                let resolvedTopBorder = resolveCellBorder(forEdge: .top, cellData: cellData, rowIndex: rowIndex, cellIndexInRow: cellIndexInRow, tableData: tableData, isFirstRowOfTable: rowIndex == 0, isFirstColOfRow: cellIndexInRow == 0 )
                                if resolvedTopBorder.isValid { drawBorderLine(context: pdfContext, start: CGPoint(x: cellRectForContinue.minX, y: cellRectForContinue.minY), end: CGPoint(x: cellRectForContinue.maxX, y: cellRectForContinue.minY), borderInfo: resolvedTopBorder) }
                                currentDrawingCellX += cellDrawingWidthPoints; continue
                            }
                            let cellDrawingRect = CGRect(x: currentDrawingCellX, y: currentY, width: cellDrawingWidthPoints, height: cellDrawingHeightPoints)
                            if let bgColor = cellData.backgroundColor { pdfContext.setFillColor(bgColor.cgColor); pdfContext.fill(cellDrawingRect) }
                            let topBorder = resolveCellBorder(forEdge: .top, cellData: cellData, rowIndex: rowIndex, cellIndexInRow: cellIndexInRow, tableData: tableData, isFirstRowOfTable: rowIndex == 0, isFirstColOfRow: false)
                            if topBorder.isValid { drawBorderLine(context: pdfContext, start: CGPoint(x: cellDrawingRect.minX, y: cellDrawingRect.minY), end: CGPoint(x: cellDrawingRect.maxX, y: cellDrawingRect.minY), borderInfo: topBorder) }
                            let leftBorder = resolveCellBorder(forEdge: .left, cellData: cellData, rowIndex: rowIndex, cellIndexInRow: cellIndexInRow, tableData: tableData, isFirstRowOfTable: false, isFirstColOfRow: cellData.originalColIndex == 0)
                            if leftBorder.isValid { drawBorderLine(context: pdfContext, start: CGPoint(x: cellDrawingRect.minX, y: cellDrawingRect.minY), end: CGPoint(x: cellDrawingRect.minX, y: cellDrawingRect.maxY), borderInfo: leftBorder) }
                            let bottomBorder = resolveCellBorder(forEdge: .bottom, cellData: cellData, rowIndex: rowIndex, cellIndexInRow: cellIndexInRow, tableData: tableData, isFirstRowOfTable: false, isFirstColOfRow: false, isLastRowOfTable: (rowIndex == tableData.rows.count - 1) || (cellData.vMerge == .restart && (rowIndex + Int(max(1, cellDrawingHeightPoints / max(1,currentRowHeightPoints) )) - 1) >= tableData.rows.count - 1) )
                            if bottomBorder.isValid { drawBorderLine(context: pdfContext, start: CGPoint(x: cellDrawingRect.minX, y: cellDrawingRect.maxY), end: CGPoint(x: cellDrawingRect.maxX, y: cellDrawingRect.maxY), borderInfo: bottomBorder) }
                            let rightBorder = resolveCellBorder(forEdge: .right, cellData: cellData, rowIndex: rowIndex, cellIndexInRow: cellIndexInRow, tableData: tableData, isFirstRowOfTable: false, isFirstColOfRow: false, isLastColOfTable: (cellData.originalColIndex + cellData.gridSpan >= columnWidths.count))
                            if rightBorder.isValid { drawBorderLine(context: pdfContext, start: CGPoint(x: cellDrawingRect.maxX, y: cellDrawingRect.minY), end: CGPoint(x: cellDrawingRect.maxX, y: cellDrawingRect.maxY), borderInfo: rightBorder) }
                            let contentRect = cellDrawingRect.inset(by: cellData.margins)
                            if contentRect.width > 0 && contentRect.height > 0 { cellData.content.draw(in: contentRect) }
                            currentDrawingCellX += cellDrawingWidthPoints
                        }
                        currentY += currentRowHeightPoints // **外部的 currentY 因表格行的绘制而更新**
                    }
                    // currentY += DocxConstants.pdfLineSpacingAfterVisibleText // 这行移到表格整体之后
                    
                    // **高亮修正点 3: 更新 lastDrawnContentHeight**
                    // 计算表格实际绘制的总高度（在当前页面或跨越多页后的总垂直位移）
                    let tableTotalRenderedHeight = currentY - tableDrawStartOriginalY
                    lastDrawnContentHeight = tableTotalRenderedHeight + DocxConstants.pdfLineSpacingAfterVisibleText // 包含表格后的间距
                    currentY += DocxConstants.pdfLineSpacingAfterVisibleText // 确保 currentY 也加上这个间距
                    
                    // 检查表格绘制完成后是否需要新页面（为下一个元素留空间）
                    if currentY + (DocxConstants.defaultFontSize * 1.2) > pageRect.height - bottomMargin {
                        if currentY > topMargin { // 确保不是表格本身填满最后一页然后又错误翻页
                            startNewPDFPage()
                        }
                    }
                    
                }
            }
            
            // --- 纯文本段落或空段落处理 ---
            if !specialObjectProcessedThisSegment {
                if paragraphAttributedStringSegment.length == 0 {
                    if searchStartIndex > 0 || currentY > topMargin + 0.1 { // +0.1 避免浮点数比较问题
                        var emptyLineHeight = DocxConstants.defaultFontSize * 1.2
                        
                        // **修正点 2 & 3 的根源**: 访问属性字典时需要有字典实例
                        // 获取前一个字符的属性，如果 searchStartIndex > 0
                        let attrsLookupIndex = searchStartIndex > 0 ? searchStartIndex - 1 : 0
                        // 确保 lookupIndex 在 attributedString 的有效范围内
                        if attrsLookupIndex < attributedString.length {
                            let prevCharAttrs = attributedString.attributes(at: attrsLookupIndex, effectiveRange: nil)
                            if let pStyle = prevCharAttrs[.paragraphStyle] as? NSParagraphStyle { // 使用 prevCharAttrs
                                let fontForMetrics = (prevCharAttrs[.font] as? UIFont) ?? // 使用 prevCharAttrs
                                UIFont(name: DocxConstants.defaultFontName, size: DocxConstants.defaultFontSize) ??
                                UIFont.systemFont(ofSize: DocxConstants.defaultFontSize)
                                var calculatedHeight = fontForMetrics.pointSize
                                if pStyle.minimumLineHeight > 0 { calculatedHeight = max(calculatedHeight, pStyle.minimumLineHeight) }
                                if pStyle.lineHeightMultiple > 0 { calculatedHeight *= pStyle.lineHeightMultiple }
                                calculatedHeight += pStyle.lineSpacing
                                calculatedHeight += pStyle.paragraphSpacing
                                emptyLineHeight = calculatedHeight
                            }
                        }
                        emptyLineHeight = max(emptyLineHeight, DocxConstants.defaultFontSize * 0.5)
                        
                        if currentY + emptyLineHeight > pageRect.height - bottomMargin {
                            if currentY > topMargin { startNewPDFPage() }
                        }
                        currentY += emptyLineHeight
                        lastDrawnContentHeight = emptyLineHeight
                    }
                } else {
                    let framesetter = CTFramesetterCreateWithAttributedString(paragraphAttributedStringSegment as CFAttributedString)
                    var currentParagraphTextPosInSegment: CFIndex = 0
                    let paragraphSegmentLength: CFIndex = paragraphAttributedStringSegment.length
                    
                    var isFirstLineOfThisParagraphSegment = true
                    
                    while currentParagraphTextPosInSegment < paragraphSegmentLength {
                        var currentLineActualHeight: CGFloat = 0
                        
                        let defaultFontForLineHeight = (paragraphAttributedStringSegment.attribute(.font, at: currentParagraphTextPosInSegment, effectiveRange: nil) as? UIFont) ??
                        UIFont(name: DocxConstants.defaultFontName, size: DocxConstants.defaultFontSize) ??
                        UIFont.systemFont(ofSize: DocxConstants.defaultFontSize)
                        var estimatedNextLineHeight = defaultFontForLineHeight.lineHeight // 使用UIFont的lineHeight属性
                        if let pStyle = paragraphAttributedStringSegment.attribute(.paragraphStyle, at: currentParagraphTextPosInSegment, effectiveRange: nil) as? NSParagraphStyle {
                            if pStyle.minimumLineHeight > 0 { estimatedNextLineHeight = pStyle.minimumLineHeight }
                            else if pStyle.maximumLineHeight > 0 && pStyle.maximumLineHeight < estimatedNextLineHeight * 3 { // 避免max过大
                                estimatedNextLineHeight = pStyle.maximumLineHeight
                            }
                            if pStyle.lineHeightMultiple > 0 { estimatedNextLineHeight *= pStyle.lineHeightMultiple }
                            estimatedNextLineHeight += pStyle.lineSpacing
                        }
                        estimatedNextLineHeight = max(estimatedNextLineHeight, defaultFontForLineHeight.pointSize * 0.8)
                        
                        if currentY + estimatedNextLineHeight > pageRect.height - bottomMargin {
                            if currentY > topMargin {
                                startNewPDFPage()
                            }
                            if currentY + estimatedNextLineHeight > pageRect.height - bottomMargin && currentY == topMargin {
                                break
                            }
                        }
                        
                        let textPathRect = CGRect(x: leftMargin, y: 0, width: printableWidth, height: pageRect.height * 2)
                        let textPath = CGPath(rect: textPathRect, transform: nil)
                        let frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(currentParagraphTextPosInSegment, 0), textPath, nil)
                        
                        guard let lines = CTFrameGetLines(frame) as? [CTLine], !lines.isEmpty else {
                            break
                        }
                        
                        let line = lines[0]
                        
                        var ascent: CGFloat = 0; var descent: CGFloat = 0; var leading: CGFloat = 0
                        CTLineGetTypographicBounds(line, &ascent, &descent, &leading)
                        currentLineActualHeight = ascent + descent + leading
                        
                        var paragraphSpacingBeforeThisLine: CGFloat = 0
                        if isFirstLineOfThisParagraphSegment {
                            if let pStyle = paragraphAttributedStringSegment.attribute(.paragraphStyle, at: currentParagraphTextPosInSegment, effectiveRange: nil) as? NSParagraphStyle {
                                paragraphSpacingBeforeThisLine = pStyle.paragraphSpacingBefore
                            }
                            isFirstLineOfThisParagraphSegment = false
                        }
                        
                        if currentY + paragraphSpacingBeforeThisLine + currentLineActualHeight > pageRect.height - bottomMargin {
                            if currentY > topMargin {
                                startNewPDFPage()
                            }
                            if currentY + paragraphSpacingBeforeThisLine + currentLineActualHeight > pageRect.height - bottomMargin && currentY == topMargin {
                                break
                            }
                        }
                        
                        currentY += paragraphSpacingBeforeThisLine
                        
                        guard let context = UIGraphicsGetCurrentContext() else {
                            throw DocParserError.pdfGenerationFailed("无法获取图形上下文用于绘制文本行")
                        }
                        context.saveGState()
                        context.textMatrix = .identity
                        context.translateBy(x: 0, y: pageRect.height)
                        context.scaleBy(x: 1.0, y: -1.0)
                        context.textPosition = CGPoint(x: leftMargin, y: pageRect.height - (currentY + ascent))
                        CTLineDraw(line, context)
                        context.restoreGState()
                        
                        currentY += currentLineActualHeight
                        lastDrawnContentHeight = currentLineActualHeight
                        
                        let lineRange = CTLineGetStringRange(line)
                        currentParagraphTextPosInSegment += lineRange.length
                    }
                    if paragraphSegmentLength > 0 {
                        if let pStyle = paragraphAttributedStringSegment.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle {
                            let paragraphSpacingAfter = pStyle.paragraphSpacing
                            if paragraphSpacingAfter > 0 {
                                if currentY + paragraphSpacingAfter > pageRect.height - bottomMargin {
                                    if currentY > topMargin + lastDrawnContentHeight + 0.1 { // +0.1 避免浮点比较问题
                                        startNewPDFPage()
                                    } else if currentY + paragraphSpacingAfter <= pageRect.height - bottomMargin {
                                        currentY += paragraphSpacingAfter
                                        lastDrawnContentHeight = paragraphSpacingAfter
                                    }
                                } else {
                                    currentY += paragraphSpacingAfter
                                    lastDrawnContentHeight = paragraphSpacingAfter
                                }
                            }
                        }
                    }
                }
            }
            searchStartIndex = nextParagraphStartIndexInFullString
        }
        UIGraphicsEndPDFContext()
        guard pdfData.length > 0 else { throw DocParserError.pdfGenerationFailed("处理完成后，生成的PDF数据为空。")}
        if let url = outputPathURL {
            do { try pdfData.write(to: url, options: .atomicWrite) }
            catch { throw DocParserError.pdfSavingFailed(error) }
        }
        return pdfData as Data
    }
}
// MARK: - Table Data Structures (表格数据结构)
extension DocParser {
    // 垂直单元格合并状态
    enum VerticalMergeStatus: String { case none, restart, `continue` }
    // 单个边框线信息
    struct TableBorderInfo: Equatable {
        enum Style: String { case single, double, dashed, dotted, nilOrNone }
        var style: Style = .nilOrNone; var width: CGFloat = 0.5; var color: UIColor = .black; var space: CGFloat = 0
        static let defaultBorder = TableBorderInfo(style: .single, width: 0.5, color: .black) // 默认边框
        static let noBorder = TableBorderInfo(style: .nilOrNone) // 无边框
        var isValid: Bool { style != .nilOrNone && width > 0 } // 是否需要绘制
    }
    // 单元格或表格默认的四边边框
    struct TableBorders {
        var top: TableBorderInfo = .noBorder; var left: TableBorderInfo = .noBorder
        var bottom: TableBorderInfo = .noBorder; var right: TableBorderInfo = .noBorder
        var insideHorizontal: TableBorderInfo = .noBorder // 内部水平线
        var insideVertical: TableBorderInfo = .noBorder   // 内部垂直线
    }
    // 单个单元格绘制数据
    struct TableCellDrawingData {
        var content: NSAttributedString; var borders: TableBorders
        var backgroundColor: UIColor?; var gridSpan: Int = 1 // 列合并
        var vMerge: VerticalMergeStatus = .none; var verticalAlignment: NSTextAlignment = .natural // TODO: 实现垂直对齐
        var margins: UIEdgeInsets = .zero; var originalRowIndex: Int = 0; var originalColIndex: Int = 0
    }
    // 表格一行绘制数据
    struct TableRowDrawingData {
        var cells: [TableCellDrawingData]; var height: CGFloat = 0 // 计算或指定的行高
        var specifiedHeight: CGFloat?; var isHeaderRow: Bool = false // 是否表头
    }
    // 整个表格绘制数据
    struct TableDrawingData {
        var rows: [TableRowDrawingData]; var columnWidthsPoints: [CGFloat] // 列宽 (Points)
        var defaultCellBorders: TableBorders; var tableIndentation: CGFloat = 0 // 表格左缩进 (Points)
    }
    // NSAttributedString中存储TableDrawingData的自定义属性键
    static let tableDrawingDataAttributeKey = NSAttributedString.Key("com.docparser.tableDrawingData")
    
    
    // 辅助函数：根据上下文决定实际要绘制的边框信息
    private enum BorderEdge { case top, left, bottom, right }
        // 这个函数需要非常小心地处理边框冲突和优先级
        private func resolveCellBorder(
            forEdge edge: BorderEdge,
            cellData: TableCellDrawingData,
            rowIndex: Int,
            cellIndexInRow: Int, // cellData在当前rowData.cells中的索引
            tableData: TableDrawingData,
            isFirstRowOfTable: Bool,
            isFirstColOfRow: Bool, // 这个指的是cellData是否为rowData.cells的第一个元素
            isLastRowOfTable: Bool = false, // 是否为表格的最后一行（或被vMerge覆盖到最后一行）
            isLastColOfTable: Bool = false  // 是否为表格的最后一列（或被gridSpan覆盖到最后一列）
        ) -> TableBorderInfo {

            let cellBorders = cellData.borders // 单元格自身的边框定义
            let defaultBorders = tableData.defaultCellBorders // 表格的默认边框

            // 简化逻辑：优先使用单元格自身定义的边框。
            // 如果单元格未定义，则根据位置使用表格的外部边框或内部边框。
            // 更完善的逻辑会比较相邻单元格的边框强度，选择更“显著”的那个。
            switch edge {
            case .top:
                // 如果单元格明确定义了上边框，则使用它
                if cellBorders.top.style != .nilOrNone { return cellBorders.top }
                // 如果是表格的第一行，使用表格的默认上边框
                if isFirstRowOfTable { return defaultBorders.top.style != .nilOrNone ? defaultBorders.top : cellBorders.top /*其实cellBorders.top已是.nilOrNone*/ }
                // 否则 (内部行)，使用表格的内部水平边框
                return defaultBorders.insideHorizontal.style != .nilOrNone ? defaultBorders.insideHorizontal : TableBorderInfo.noBorder


            case .left:
                if cellBorders.left.style != .nilOrNone { return cellBorders.left }
                // cellData.originalColIndex == 0 判断是否为逻辑上的第一列
                if cellData.originalColIndex == 0 { return defaultBorders.left.style != .nilOrNone ? defaultBorders.left : cellBorders.left }
                return defaultBorders.insideVertical.style != .nilOrNone ? defaultBorders.insideVertical : TableBorderInfo.noBorder

            case .bottom:
                if cellBorders.bottom.style != .nilOrNone { return cellBorders.bottom }
                // isLastRowOfTable 标志由调用者传入，判断是否为表格物理最后一行或vMerge延伸到的最后一行
                if isLastRowOfTable { return defaultBorders.bottom.style != .nilOrNone ? defaultBorders.bottom : cellBorders.bottom }
                return defaultBorders.insideHorizontal.style != .nilOrNone ? defaultBorders.insideHorizontal : TableBorderInfo.noBorder

            case .right:
                if cellBorders.right.style != .nilOrNone { return cellBorders.right }
                // isLastColOfTable 标志由调用者传入，判断是否为表格物理最后一列或gridSpan延伸到的最后一列
                if isLastColOfTable { return defaultBorders.right.style != .nilOrNone ? defaultBorders.right : cellBorders.right }
                return defaultBorders.insideVertical.style != .nilOrNone ? defaultBorders.insideVertical : TableBorderInfo.noBorder
            }
        }


        // 辅助函数：绘制单条边框线
        private func drawBorderLine(context: CGContext, start: CGPoint, end: CGPoint, borderInfo: TableBorderInfo) {
            guard borderInfo.isValid else { return } // 无效边框不绘制

            context.saveGState() // 保存当前图形状态
            context.setStrokeColor(borderInfo.color.cgColor) // 设置线条颜色
            context.setLineWidth(borderInfo.width)         // 设置线条宽度

            // 处理虚线、点线等样式
            switch borderInfo.style {
            case .dashed:
                let dashPattern: [CGFloat] = [borderInfo.width * 3, borderInfo.width * 3] // 示例：3倍线宽实线，3倍线宽空白
                context.setLineDash(phase: 0, lengths: dashPattern)
            case .dotted:
                let dotPattern: [CGFloat] = [borderInfo.width, borderInfo.width] // 示例：线宽长度实线，线宽长度空白
                context.setLineDash(phase: 0, lengths: dotPattern)
            case .double:
                // 双线需要绘制两条平行的细线。这里简化为绘制一条线，或需要更复杂偏移绘制。
                // 暂时按单线处理，或可以增加宽度模拟。
                // 若要画两条，需要计算偏移，如：
                // context.setLineWidth(borderInfo.width / 3) // 每条线是总宽度的1/3
                // let offset = borderInfo.width / 3
                // context.move(to: CGPoint(x: start.x, y: start.y - offset)); context.addLine(to: CGPoint(x: end.x, y: end.y - offset)); context.strokePath()
                // context.move(to: CGPoint(x: start.x, y: start.y + offset)); context.addLine(to: CGPoint(x: end.x, y: end.y + offset)); context.strokePath()
                // context.restoreGState(); return
                break // 默认按单线处理
            default: // .single 或其他未特殊处理的样式
                break
            }

            context.move(to: start)    // 移动到起点
            context.addLine(to: end)   // 添加到终点的线段
            context.strokePath()       // 绘制路径
            context.restoreGState()    // 恢复之前保存的图形状态
        }
}




// MARK: - UIColor Hex Initializer, XMLIndexer/String extensions (UIColor十六进制初始化器, XMLIndexer/String扩展)
extension UIColor {
    // 从十六进制字符串 (例如 "RRGGBB" 或 "#RRGGBB") 初始化颜色
    convenience init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines) // 移除首尾空白
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "") // 移除 "#" 前缀
        var rgb: UInt64 = 0 // 用于存储扫描到的十六进制值
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil } // 扫描失败则返回nil
        let r, g, b: CGFloat
        if hexSanitized.count == 6 { // 仅支持RRGGBB
            r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0; g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
            b = CGFloat(rgb & 0x0000FF) / 255.0
        } else { return nil } // 其他长度不支持
        self.init(red: r, green: g, blue: b, alpha: 1.0) // alpha默认为1.0
    }
}
extension XMLIndexer {
    // 深度优先搜索 (BFS) 具有匹配名称的元素
    func deepSearch(elements names: [String]) -> [XMLIndexer] {
        var results: [XMLIndexer] = []; var queue: [XMLIndexer] = [self] // 初始化队列
        while !queue.isEmpty {
            let current = queue.removeFirst() // 取出队首
            if let elementName = current.element?.name, names.contains(elementName) { results.append(current) } // 匹配则添加
            queue.append(contentsOf: current.children) // 子元素入队
        }
        return results
    }
}
extension String {
    // 从样式字符串中提取特定键的值 (如 "width:100pt" -> 100.0)
    func extractValue(forKey key: String, unit: String) -> CGFloat? {
           let pattern = "\(key):\\s*([0-9.]+)\\s*\(unit)" // 正则表达式
           if let swiftRange = self.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
               let matchedSubstring = String(self[swiftRange])
               if let valueString = matchedSubstring.matches(for: pattern).first?.last, // 获取捕获组
                  let value = Double(valueString) {
                   return CGFloat(value)
               }
           }
           return nil
       }
    // 辅助函数：获取正则匹配的捕获组
    func matches(for regex: String) -> [[String]] {
        do {
            let regex = try NSRegularExpression(pattern: regex)
            let results = regex.matches(in: self, range: NSRange(self.startIndex..., in: self))
            return results.map { result in
                return (0..<result.numberOfRanges).map {
                    result.range(at: $0).location != NSNotFound
                        ? String(self[Range(result.range(at: $0), in: self)!]) : "" // 提取捕获组字符串
                }
            }
        } catch { /* print("无效正则: \(error)") */ return [] }
    }
     // 辅助函数：从NSRange获取子字符串
     func substring(with nsrange: NSRange) -> String? {
         guard let range = Range(nsrange, in: self) else { return nil }
         return String(self[range])
     }
}
