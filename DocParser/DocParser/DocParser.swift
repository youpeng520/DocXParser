// DocParser.swift
import Foundation
import Zip
import SWXMLHash
import UIKit

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
               
               // --- 修改点：移除硬编码的 "•" 占位符 ---
               // 原始逻辑会在这里定义一个 numberPlaceholder = "•" 并将其与 indent 组合。
               // 例如:
               //   let numberPlaceholder = "•"
               //   listItemPrefix = indent + numberPlaceholder + " "
               //
               // 新逻辑：仅使用计算出的缩进作为前缀。
               // "•" 字符及其后的空格已被移除。
               // 如果未来实现了 numbering.xml 的解析，这里的逻辑需要更新，
               // 以便使用从 numbering.xml 中获取的实际列表标记来替换或增强此处的 indent。
               listItemPrefix = indent // 仅保留缩进，移除了 "•" 和其后的空格
               
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
           return paragraphAttributedString
       }
    // MARK: - Paragraph Property Parsing (Revised for Styles) (段落属性解析 - 已为样式修改)
    /**
     * 解析 <w:pPr> (段落属性) 元素，综合考虑文档默认样式、命名段落样式及直接定义的属性。
     * - Parameter pPrNode: 指向 <w:pPr> 节点的 XMLIndexer。
     * - Returns: 一个元组，包含最终生效的段落级属性 (paragraphAttributes) 和此段落内文本运行的默认属性 (runAttributes)。
     */
    private func parseParagraphProperties(fromPPrNode pPrNode: XMLNode) throws -> (paragraphAttributes: Attributes, runAttributes: Attributes) {
        var effectiveParagraphAttributes = Attributes() // 最终生效的段落属性
        var effectiveRunAttributes = Attributes()       // 最终生效的、此段落内容的默认运行属性

        // 1. 初始：从 StyleParser 获取文档的默认段落样式属性 (包括其默认运行属性)
        let (docDefaultParaAttrs, docDefaultRunAttrs) = styleParser.getDefaultParagraphStyleAttributes()
        effectiveParagraphAttributes.merge(docDefaultParaAttrs) { _, new in new } // 合并段落属性
        effectiveRunAttributes.merge(docDefaultRunAttrs) { _, new in new }       // 合并运行属性
        
        // 2. 应用段落命名样式 (如果 <w:pStyle w:val="StyleID"/> 存在)
        // 命名样式会覆盖文档默认样式。
        if let pStyleId = pPrNode["w:pStyle"].attributeValue(by: "w:val") {
            let (namedParaStyleAttrs, namedRunStyleAttrs) = styleParser.getResolvedAttributes(forStyleId: pStyleId)
            effectiveParagraphAttributes.merge(namedParaStyleAttrs) { _, new in new } // 段落属性，命名样式优先
            effectiveRunAttributes.merge(namedRunStyleAttrs) { _, new in new }       // 运行属性，命名样式优先
        }

        // 3. 基于当前积累的属性创建或修改 NSParagraphStyle 对象
        //    直接在 <w:pPr> 中定义的属性 (如 <w:jc>, <w:ind>) 会覆盖从样式继承来的相应部分。
        let paragraphStyleToModify: NSMutableParagraphStyle
        if let existingStyle = effectiveParagraphAttributes[.paragraphStyle] as? NSParagraphStyle {
            paragraphStyleToModify = existingStyle.mutableCopy() as! NSMutableParagraphStyle
        } else { // 如果之前没有解析到NSParagraphStyle (例如样式中未定义)，则新建一个
            paragraphStyleToModify = NSMutableParagraphStyle()
            // 设置一些NSParagraphStyle的绝对基础默认值，以防万一XML和样式都没有定义
            paragraphStyleToModify.alignment = .natural
            paragraphStyleToModify.lineHeightMultiple = 1.0
        }

        // 4. 解析 <w:pPr> 中直接定义的属性，并修改 paragraphStyleToModify 对象
        // 对齐
        if let alignVal = pPrNode["w:jc"].attributeValue(by: "w:val") {
            switch alignVal.lowercased() {
            case "left", "start": paragraphStyleToModify.alignment = .left
            case "right", "end": paragraphStyleToModify.alignment = .right
            case "center": paragraphStyleToModify.alignment = .center
            case "both", "distribute", "justify": paragraphStyleToModify.alignment = .justified
            default: break // 未指定或未知值，则保持从样式继承的值
            }
        }

        // 缩进
        let twipsPerPoint: CGFloat = 20.0
        let indNode = pPrNode["w:ind"]
        if indNode.element != nil { // 如果存在 <w:ind> 标签
            // 基础左缩进 (headIndent)
            // 如果 <w:ind> 中直接定义了 left/start，则覆盖从样式继承的 headIndent
            // 否则，保留样式中的 headIndent，后续 firstLine/hanging 会基于它调整
            var baseLeftIndent = paragraphStyleToModify.headIndent
            if let leftValStr = indNode.attributeValue(by: "w:left") ?? indNode.attributeValue(by: "w:start"), let val = Double(leftValStr) {
                baseLeftIndent = CGFloat(val) / twipsPerPoint
                paragraphStyleToModify.headIndent = baseLeftIndent
            }

            // 首行缩进 (firstLineHeadIndent)
            // OOXML 的 w:firstLine 和 w:hanging 是绝对值或相对于 0 的值。
            // NSParagraphStyle 的 firstLineHeadIndent 是相对于 headIndent 的偏移。
            // 因此，如果 firstLine/hanging 被直接定义，我们需要计算相对于 *新* headIndent 的偏移。
            // 但更常见的是，w:firstLine/hanging 定义了首行的绝对缩进，而 headIndent 定义了后续行的绝对缩进。
            // 这里我们采用后一种理解：直接设置 firstLineHeadIndent 和 headIndent。

            if let firstLineValStr = indNode.attributeValue(by: "w:firstLine"), let val = Double(firstLineValStr) {
                 // w:firstLine 直接指定首行缩进的绝对值
                 paragraphStyleToModify.firstLineHeadIndent = CGFloat(val) / twipsPerPoint
                 // headIndent 已经设置（可能来自样式或上方直接的 w:left/start）
            } else if let hangingValStr = indNode.attributeValue(by: "w:hanging"), let val = Double(hangingValStr)  {
                 // w:hanging 指定悬挂量。首行在 baseLeftIndent，后续行在 baseLeftIndent + hangingAmount
                 let hangingAmount = CGFloat(val) / twipsPerPoint
                 paragraphStyleToModify.firstLineHeadIndent = baseLeftIndent // 首行在基础左缩进处
                 paragraphStyleToModify.headIndent = baseLeftIndent + hangingAmount  // 后续行更靠右
             } else if pPrNode["w:ind"].attributeValue(by: "w:left") != nil || pPrNode["w:ind"].attributeValue(by: "w:start") != nil || pPrNode["w:ind"].attributeValue(by: "w:firstLine") != nil || pPrNode["w:ind"].attributeValue(by: "w:hanging") != nil {
                 // 如果 <w:ind> 存在，但没有显式的 w:firstLine 或 w:hanging，
                 // 那么首行缩进就等于 headIndent (非悬挂，非特殊首行)
                 paragraphStyleToModify.firstLineHeadIndent = paragraphStyleToModify.headIndent
             }
             // 如果 <w:ind> 完全不存在，则 firstLineHeadIndent 和 headIndent 保持从样式继承。
        }
        
        // 间距
        if let spacingNode = pPrNode["w:spacing"].element {
            // 段前间距
            if let beforeStr = spacingNode.attribute(by: "w:before")?.text, let val = Double(beforeStr) {
                paragraphStyleToModify.paragraphSpacingBefore = CGFloat(val) / twipsPerPoint
            }
            // 段后间距
            if let afterStr = spacingNode.attribute(by: "w:after")?.text, let val = Double(afterStr) {
                paragraphStyleToModify.paragraphSpacing = CGFloat(val) / twipsPerPoint // NSParagraphStyle 的 paragraphSpacing 是段后
            }
            
            // 行距
            // var ruleApplied = false // 标记是否应用了直接的行距规则
            if let lineValStr = spacingNode.attribute(by: "w:line")?.text, let lineVal = Double(lineValStr) {
                 let lineRule = spacingNode.attribute(by: "w:lineRule")?.text.lowercased()
                 switch lineRule {
                 case "auto": // lineVal 是 240 的倍数，表示行高倍数
                      paragraphStyleToModify.lineHeightMultiple = CGFloat(lineVal) / 240.0
                      paragraphStyleToModify.minimumLineHeight = 0; paragraphStyleToModify.maximumLineHeight = 0 // 清除固定行高
                      // ruleApplied = true
                 case "exact": // lineVal 是 Twips，固定行高
                      let exactHeight = CGFloat(lineVal) / twipsPerPoint
                      paragraphStyleToModify.minimumLineHeight = exactHeight; paragraphStyleToModify.maximumLineHeight = exactHeight
                      paragraphStyleToModify.lineHeightMultiple = 0 // 使用固定行高时，倍数应为0
                      // ruleApplied = true
                 case "atleast": // lineVal 是 Twips，最小行高
                      paragraphStyleToModify.minimumLineHeight = CGFloat(lineVal) / twipsPerPoint
                      paragraphStyleToModify.maximumLineHeight = 0; paragraphStyleToModify.lineHeightMultiple = 0 // 倍数为0
                      // ruleApplied = true
                 default: // 包括 lineRule 未指定 (视为 'multiple') 或 "multiple"
                      if lineRule == nil || lineRule == "multiple" { // 明确处理这两种常见情况
                          paragraphStyleToModify.lineHeightMultiple = CGFloat(lineVal) / 240.0
                          paragraphStyleToModify.minimumLineHeight = 0; paragraphStyleToModify.maximumLineHeight = 0
                          // ruleApplied = true
                      }
                 }
             }
        }
        // 将修改后的 NSParagraphStyle 对象存回属性字典
        effectiveParagraphAttributes[.paragraphStyle] = paragraphStyleToModify.copy()

        // 5. 解析 <w:pPr><w:rPr> (段落属性中定义的默认运行属性)，并合并到 effectiveRunAttributes
        // 这些会覆盖从段落样式或文档默认样式继承来的运行属性。
        if pPrNode["w:rPr"].element != nil { // 检查 <w:pPr> 下是否有 <w:rPr>
            // `parseRunPropertiesFromNode` 会基于 `effectiveRunAttributes` (已包含样式信息)
            // 并应用 `pPrNode["w:rPr"]` 中的直接定义。
            let directPPrRunAttrs = parseRunPropertiesFromNode(runPropertyXML: pPrNode["w:rPr"], baseAttributes: effectiveRunAttributes)
            effectiveRunAttributes.merge(directPPrRunAttrs) { _, new in new } // directPPrRunAttrs 优先
        }
        
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
     * - Parameter runPropertyXML: 指向 <w:rPr> 节点的 XMLIndexer。
     * - Parameter baseAttributes: 作为基础的运行属性字典 (可能来自段落默认或字符样式)。
     * - Returns: 包含最终生效的运行属性的字典。
     */
    private func parseRunPropertiesFromNode(runPropertyXML: XMLNode, baseAttributes: Attributes) -> Attributes {
        var attributes = baseAttributes // 从基础属性开始

        // 从基础属性中提取初始值，以便直接格式化可以覆盖它们
        var currentFont = baseAttributes[.font] as? UIFont
        var fontSize = currentFont?.pointSize ?? DocxConstants.defaultFontSize
        var fontNameFromDocx: String? = currentFont?.fontName // 默认使用基础字体名
        
        var isBold = currentFont?.fontDescriptor.symbolicTraits.contains(.traitBold) ?? false
        var isItalic = currentFont?.fontDescriptor.symbolicTraits.contains(.traitItalic) ?? false
        var isUnderline = (baseAttributes[.underlineStyle] as? NSNumber)?.intValue == NSUnderlineStyle.single.rawValue
        var isStrikethrough = (baseAttributes[.strikethroughStyle] as? NSNumber)?.intValue == NSUnderlineStyle.single.rawValue
        var foregroundColor = baseAttributes[.foregroundColor] as? UIColor ?? UIColor.black // 默认黑色
        var highlightColor = baseAttributes[.backgroundColor] as? UIColor // 可能为nil
        var verticalAlign: Int = 0 // 0: 基线, 1: 上标, 2: 下标
        // 从基线偏移量粗略推断垂直对齐状态
        if let baselineOffset = baseAttributes[.baselineOffset] as? CGFloat {
            if baselineOffset > 0.1 * fontSize { verticalAlign = 1 }
            else if baselineOffset < -0.1 * fontSize { verticalAlign = 2 }
        }

        // --- 解析来自 runPropertyXML (<w:rPr>) 的直接覆盖属性 ---
        // 字体大小
        if let szStr = runPropertyXML["w:sz"].attributeValue(by: "w:val") ?? runPropertyXML["w:szCs"].attributeValue(by: "w:val"),
           let sizeValHalfPoints = Double(szStr) {
            fontSize = CGFloat(sizeValHalfPoints) / 2.0
        }

        // 字体名称
        let rFontsNode = runPropertyXML["w:rFonts"]
        if rFontsNode.element != nil {
            fontNameFromDocx = rFontsNode.attributeValue(by: "w:ascii") ??
                               rFontsNode.attributeValue(by: "w:hAnsi") ??
                               rFontsNode.attributeValue(by: "w:eastAsia") ??
                               rFontsNode.attributeValue(by: "w:cs") ?? fontNameFromDocx
        }

        // 粗体
        if runPropertyXML["w:b"].element != nil {
            isBold = runPropertyXML["w:b"].attributeValue(by: "w:val") != "0" && runPropertyXML["w:b"].attributeValue(by: "w:val") != "false"
        } else if runPropertyXML["w:bCs"].element != nil {
            isBold = runPropertyXML["w:bCs"].attributeValue(by: "w:val") != "0" && runPropertyXML["w:bCs"].attributeValue(by: "w:val") != "false"
        }
        // 斜体
        if runPropertyXML["w:i"].element != nil {
            isItalic = runPropertyXML["w:i"].attributeValue(by: "w:val") != "0" && runPropertyXML["w:i"].attributeValue(by: "w:val") != "false"
        } else if runPropertyXML["w:iCs"].element != nil {
            isItalic = runPropertyXML["w:iCs"].attributeValue(by: "w:val") != "0" && runPropertyXML["w:iCs"].attributeValue(by: "w:val") != "false"
        }
        
        // 下划线
        if let uNode = runPropertyXML["w:u"].element {
            let uVal = uNode.attribute(by: "w:val")?.text.lowercased()
            isUnderline = !(uVal == "none" || uVal == "0")
        }

        // 删除线
        if runPropertyXML["w:strike"].element != nil {
            isStrikethrough = runPropertyXML["w:strike"].attributeValue(by: "w:val") != "0" && runPropertyXML["w:strike"].attributeValue(by: "w:val") != "false"
        } else if runPropertyXML["w:dstrike"].element != nil {
             isStrikethrough = runPropertyXML["w:dstrike"].attributeValue(by: "w:val") != "0" && runPropertyXML["w:dstrike"].attributeValue(by: "w:val") != "false"
        }

        // 文本颜色
        if let colorValHex = runPropertyXML["w:color"].attributeValue(by: "w:val") {
            if colorValHex.lowercased() == "auto" {
                 foregroundColor = styleParser.getDefaultCharacterStyleAttributes()[.foregroundColor] as? UIColor ?? UIColor.black
            } else if let color = UIColor(hex: colorValHex) {
                foregroundColor = color
            }
        }
        
        // 高亮颜色
         if let highlightVal = runPropertyXML["w:highlight"].attributeValue(by: "w:val") {
             if highlightVal.lowercased() == "none" {
                 highlightColor = nil
             } else {
                 highlightColor = mapHighlightColor(highlightVal) ?? highlightColor
             }
         }

        // 垂直对齐 (上标/下标)
        if let vertAlignVal = runPropertyXML["w:vertAlign"].attributeValue(by: "w:val") {
            switch vertAlignVal.lowercased() {
            case "superscript": verticalAlign = 1
            case "subscript": verticalAlign = 2
            default: verticalAlign = 0
            }
        }

        // -- 构建最终字体并更新属性字典 --
        var traits: UIFontDescriptor.SymbolicTraits = []
        if isBold { traits.insert(.traitBold) }
        if isItalic { traits.insert(.traitItalic) }

        var finalFont: UIFont?
        let effectiveFontName = fontNameFromDocx ?? DocxConstants.defaultFontName

        // 尝试创建字体
        if let baseFontAttempt = UIFont(name: effectiveFontName, size: fontSize) {
            if !traits.isEmpty, let fontDescriptorWithTraits = baseFontAttempt.fontDescriptor.withSymbolicTraits(traits) {
                finalFont = UIFont(descriptor: fontDescriptorWithTraits, size: fontSize)
            } else {
                finalFont = baseFontAttempt
            }
        } else {
            let systemFont = UIFont.systemFont(ofSize: fontSize)
            if !traits.isEmpty, let fontDescriptorWithTraits = systemFont.fontDescriptor.withSymbolicTraits(traits) {
                finalFont = UIFont(descriptor: fontDescriptorWithTraits, size: fontSize)
            } else {
                finalFont = systemFont
            }
        }
        
        // 应用最终计算出的属性
        if let font = finalFont { attributes[.font] = font }
        attributes[.foregroundColor] = foregroundColor
        
        if isUnderline { attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue }
        else { attributes.removeValue(forKey: .underlineStyle) }
        
        if isStrikethrough { attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue }
        else { attributes.removeValue(forKey: .strikethroughStyle) }
        
        if let bgColor = highlightColor { attributes[.backgroundColor] = bgColor }
        else { attributes.removeValue(forKey: .backgroundColor) }
        
        // 处理上标/下标的基线偏移和字体大小调整
        if verticalAlign != 0 {
            let actualFontSizeForOffset = (finalFont ?? UIFont.systemFont(ofSize: fontSize)).pointSize
            attributes[.baselineOffset] = (verticalAlign == 1) ? (actualFontSizeForOffset * 0.35) : -(actualFontSizeForOffset * 0.20)
            
            if let currentBaseFont = finalFont {
                let targetSize = actualFontSizeForOffset * 0.75
                if let smallerFontDescriptor = currentBaseFont.fontDescriptor.withSymbolicTraits(traits) {
                     attributes[.font] = UIFont(descriptor: smallerFontDescriptor, size: targetSize)
                } else {
                    attributes[.font] = UIFont(name: currentBaseFont.fontName, size: targetSize) ?? UIFont.systemFont(ofSize: targetSize)
                }
            }
        } else {
            attributes.removeValue(forKey: .baselineOffset)
            
            if let currentF = attributes[.font] as? UIFont, currentF.pointSize != fontSize {
                if let restoredFontDescriptor = currentF.fontDescriptor.withSymbolicTraits(traits) {
                     attributes[.font] = UIFont(descriptor: restoredFontDescriptor, size: fontSize)
                } else {
                    attributes[.font] = UIFont(name: currentF.fontName, size: fontSize) ?? UIFont.systemFont(ofSize: fontSize)
                }
            }
        }
        return attributes
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
                    if shdIndexer.element != nil,
                       let fillHex = shdIndexer.attributeValue(by: "w:fill"),
                       fillHex.lowercased() != "auto",
                       let color = UIColor(hex: fillHex) {
                        cellBackgroundColor = color
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
        attributedString: NSAttributedString,
        outputPathURL: URL? = nil
    ) throws -> Data {
        guard attributedString.length > 0 else {
            throw DocParserError.pdfGenerationFailed("输入的 NSAttributedString 为空，无法生成PDF。")
        }
        let pageRect = DocxConstants.defaultPDFPageRect
        let topMargin = DocxConstants.defaultPDFMargins.top
        let bottomMargin = DocxConstants.defaultPDFMargins.bottom
        let leftMargin = DocxConstants.defaultPDFMargins.left
        let rightMargin = DocxConstants.defaultPDFMargins.right
        let lineSpacingAfterVisibleText = DocxConstants.pdfLineSpacingAfterVisibleText
        let imageBottomPadding = DocxConstants.pdfImageBottomPadding
        let printableWidth = pageRect.width - leftMargin - rightMargin
        let printablePageHeight = pageRect.height - topMargin - bottomMargin

        let pdfData = NSMutableData()
        UIGraphicsBeginPDFContextToData(pdfData, pageRect, nil)
//        defer { UIGraphicsEndPDFContext() }
        
        UIGraphicsBeginPDFPageWithInfo(pageRect, nil)
        var currentY: CGFloat = topMargin

        func startNewPage() {
            UIGraphicsBeginPDFPageWithInfo(pageRect, nil)
            currentY = topMargin
        }

        attributedString.enumerateAttributes(in: NSRange(location: 0, length: attributedString.length), options: []) { attrs, range, _ in
            if let attachment = attrs[.attachment] as? NSTextAttachment, var imageToDraw = attachment.image {
                let originalImageRef = imageToDraw
                var currentImageSize = imageToDraw.size
                if currentImageSize.width > printableWidth {
                    let scaleFactor = printableWidth / currentImageSize.width
                    currentImageSize = CGSize(width: printableWidth, height: currentImageSize.height * scaleFactor)
                }
                if currentImageSize.height > printablePageHeight {
                    let scaleFactor = printablePageHeight / currentImageSize.height
                    currentImageSize = CGSize(width: currentImageSize.width * scaleFactor, height: printablePageHeight)
                }
                if imageToDraw.size != currentImageSize && currentImageSize.width > 0 && currentImageSize.height > 0 {
                    UIGraphicsBeginImageContextWithOptions(currentImageSize, false, 0.0)
                    originalImageRef.draw(in: CGRect(origin: .zero, size: currentImageSize))
                    imageToDraw = UIGraphicsGetImageFromCurrentImageContext() ?? originalImageRef
                    UIGraphicsEndImageContext()
                }
                if currentY + imageToDraw.size.height > pageRect.height - bottomMargin {
                    if currentY > topMargin {
                        startNewPage()
                    }
                }
                if imageToDraw.size.height > 0 {
                    let imageDrawRect = CGRect(x: leftMargin,
                                               y: currentY,
                                               width: imageToDraw.size.width,
                                               height: imageToDraw.size.height)
                    imageToDraw.draw(in: imageDrawRect)
                    currentY += imageToDraw.size.height
                }
                currentY += imageBottomPadding
            } else if let tableData = attrs[DocParser.tableDrawingDataAttributeKey] as? DocParser.TableDrawingData {
                guard let pdfContext = UIGraphicsGetCurrentContext() else {
                    currentY += 20
                    return
                }
                let tableOriginX = leftMargin + tableData.tableIndentation
                var currentTableContentY = currentY
                let estimatedMinRowHeightPoints: CGFloat = 20
                if currentTableContentY + estimatedMinRowHeightPoints > pageRect.height - bottomMargin && currentTableContentY > topMargin {
                    startNewPage()
                    currentTableContentY = topMargin
                }
                currentY = currentTableContentY
                let columnWidths = tableData.columnWidthsPoints
                var calculatedRowYOrigins: [CGFloat] = []
                var calculatedRowHeights: [CGFloat] = []

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

                var currentDrawingCellX = tableOriginX
                for (rowIndex, rowData) in tableData.rows.enumerated() {
                    let currentRowHeightPoints = calculatedRowHeights[rowIndex]
                    calculatedRowYOrigins.append(currentY)
                    if currentY + currentRowHeightPoints > pageRect.height - bottomMargin {
                        if currentY > topMargin {
                           startNewPage()
                           currentY = topMargin
                           calculatedRowYOrigins[rowIndex] = currentY
                        }
                    }
                    currentDrawingCellX = tableOriginX
                    for (cellIndexInRow, cellData) in rowData.cells.enumerated() {
                        var cellDrawingWidthPoints: CGFloat = 0
                        for spanIdx in 0..<cellData.gridSpan {
                            if (cellData.originalColIndex + spanIdx) < columnWidths.count {
                                cellDrawingWidthPoints += columnWidths[cellData.originalColIndex + spanIdx]
                            }
                        }
                        if cellDrawingWidthPoints <= 0 { cellDrawingWidthPoints = 50 }
                        var cellDrawingHeightPoints = currentRowHeightPoints
                        if cellData.vMerge == .restart {
                            cellDrawingHeightPoints = 0
                            for rIdx in rowIndex..<tableData.rows.count {
                                let spannedRowData = tableData.rows[rIdx]
                                var currentLogicalColForSearch = 0
                                var targetCellInSpannedRow: TableCellDrawingData? = nil
                                for c_search in spannedRowData.cells {
                                    if currentLogicalColForSearch == cellData.originalColIndex {
                                        targetCellInSpannedRow = c_search
                                        break
                                    }
                                    currentLogicalColForSearch += c_search.gridSpan
                                }
                                if let actualCellInSpannedRow = targetCellInSpannedRow,
                                   (rIdx == rowIndex || actualCellInSpannedRow.vMerge == .continue) {
                                    cellDrawingHeightPoints += calculatedRowHeights[rIdx]
                                } else { break }
                            }
                        } else if cellData.vMerge == .continue {
                            let cellRectForContinue = CGRect(x: currentDrawingCellX, y: currentY, width: cellDrawingWidthPoints, height: currentRowHeightPoints)
                            let resolvedTopBorder = resolveCellBorder(
                                forEdge: .top, cellData: cellData, rowIndex: rowIndex, cellIndexInRow: cellIndexInRow,
                                tableData: tableData, isFirstRowOfTable: rowIndex == 0, isFirstColOfRow: cellIndexInRow == 0
                            )
                            if resolvedTopBorder.isValid {
                                drawBorderLine(context: pdfContext,
                                               start: CGPoint(x: cellRectForContinue.minX, y: cellRectForContinue.minY),
                                               end: CGPoint(x: cellRectForContinue.maxX, y: cellRectForContinue.minY),
                                               borderInfo: resolvedTopBorder)
                            }
                            currentDrawingCellX += cellDrawingWidthPoints
                            continue
                        }
                        let cellDrawingRect = CGRect(x: currentDrawingCellX,
                                                     y: currentY,
                                                     width: cellDrawingWidthPoints,
                                                     height: cellDrawingHeightPoints)
                        if let bgColor = cellData.backgroundColor {
                            pdfContext.setFillColor(bgColor.cgColor)
                            pdfContext.fill(cellDrawingRect)
                        }
                        let topBorder = resolveCellBorder(forEdge: .top, cellData: cellData, rowIndex: rowIndex, cellIndexInRow: cellIndexInRow, tableData: tableData, isFirstRowOfTable: rowIndex == 0, isFirstColOfRow: false)
                        if topBorder.isValid {
                            drawBorderLine(context: pdfContext, start: CGPoint(x: cellDrawingRect.minX, y: cellDrawingRect.minY), end: CGPoint(x: cellDrawingRect.maxX, y: cellDrawingRect.minY), borderInfo: topBorder)
                        }
                        let leftBorder = resolveCellBorder(forEdge: .left, cellData: cellData, rowIndex: rowIndex, cellIndexInRow: cellIndexInRow, tableData: tableData, isFirstRowOfTable: false, isFirstColOfRow: cellData.originalColIndex == 0)
                        if leftBorder.isValid {
                             drawBorderLine(context: pdfContext, start: CGPoint(x: cellDrawingRect.minX, y: cellDrawingRect.minY), end: CGPoint(x: cellDrawingRect.minX, y: cellDrawingRect.maxY), borderInfo: leftBorder)
                        }
                        let bottomBorder = resolveCellBorder(forEdge: .bottom, cellData: cellData, rowIndex: rowIndex, cellIndexInRow: cellIndexInRow, tableData: tableData, isFirstRowOfTable: false, isFirstColOfRow: false, isLastRowOfTable: (rowIndex == tableData.rows.count - 1) || (cellData.vMerge == .restart && (rowIndex + Int(max(1, cellDrawingHeightPoints / max(1,currentRowHeightPoints) )) - 1) >= tableData.rows.count - 1) )
                        if bottomBorder.isValid {
                            drawBorderLine(context: pdfContext, start: CGPoint(x: cellDrawingRect.minX, y: cellDrawingRect.maxY), end: CGPoint(x: cellDrawingRect.maxX, y: cellDrawingRect.maxY), borderInfo: bottomBorder)
                        }
                        let rightBorder = resolveCellBorder(forEdge: .right, cellData: cellData, rowIndex: rowIndex, cellIndexInRow: cellIndexInRow, tableData: tableData, isFirstRowOfTable: false, isFirstColOfRow: false, isLastColOfTable: (cellData.originalColIndex + cellData.gridSpan >= columnWidths.count))
                        if rightBorder.isValid {
                            drawBorderLine(context: pdfContext, start: CGPoint(x: cellDrawingRect.maxX, y: cellDrawingRect.minY), end: CGPoint(x: cellDrawingRect.maxX, y: cellDrawingRect.maxY), borderInfo: rightBorder)
                        }
                        let contentRect = cellDrawingRect.inset(by: cellData.margins)
                        if contentRect.width > 0 && contentRect.height > 0 {
                            cellData.content.draw(in: contentRect)
                        }
                        currentDrawingCellX += cellDrawingWidthPoints
                    }
                    currentY += currentRowHeightPoints
                }
                currentY += DocxConstants.pdfLineSpacingAfterVisibleText
            } else {
                let textSegment = attributedString.attributedSubstring(from: range)
                let segmentString = textSegment.string
                let textBoundingRect = textSegment.boundingRect(
                    with: CGSize(width: printableWidth, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    context: nil
                )
                let textHeight = ceil(textBoundingRect.height)
                if currentY + textHeight > pageRect.height - bottomMargin {
                    if currentY > topMargin {
                       startNewPage()
                    }
                }
                if textHeight > 0 {
                    let drawRect = CGRect(x: leftMargin, y: currentY, width: printableWidth, height: textHeight)
                    textSegment.draw(in: drawRect)
                }
                currentY += textHeight
                let trimmedSegmentString = segmentString.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmedSegmentString.isEmpty {
                    currentY += lineSpacingAfterVisibleText
                }
            }
        }
        UIGraphicsEndPDFContext()
        guard pdfData.length > 0 else {
            throw DocParserError.pdfGenerationFailed("处理完成后，生成的PDF数据为空。")
        }
        if let url = outputPathURL {
            do {
                try pdfData.write(to: url, options: .atomicWrite)
            } catch {
                throw DocParserError.pdfSavingFailed(error)
            }
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
