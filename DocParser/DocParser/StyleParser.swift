//
//  StyleParser.swift
//  DocParser
//
//  Created by ZJS on 2025/5/8.
//  Copyright © 2025 paf. All rights reserved.
//

import Foundation
import SWXMLHash
import UIKit

// MARK: - StyleParser Error (样式解析器错误枚举)
enum StyleParserError: Error {
    case fileNotFound(String)        // styles.xml 文件未找到
    case xmlParsingFailed(Error)     // XML 解析失败
}

// MARK: - Style Data Structures (样式数据结构)
class StyleParser {
    typealias XMLNode = XMLIndexer  // XML节点的类型别名
    typealias Attributes = [NSAttributedString.Key: Any] // NSAttributedString属性字典的类型别名

    // 样式类型
    enum StyleType: String {
        case paragraph = "paragraph" // 段落样式
        case character = "character" // 字符样式
        case table = "table"         // 表格样式
        case numbering = "numbering" // 编号样式 (在此范围内未完全处理)
    }

    // 存储单个样式定义的结构体
    struct StyleDefinition {
        let styleId: String                    // 样式ID，如 "Normal", "Heading1"
        let type: StyleType                    // 样式类型
        let name: String?                      // 样式名称 (可选，用户可见名称)
        let basedOn: String?                   // 继承的父样式ID (基于此样式)
        let isDefault: Bool                    // 此样式是否为其类型的默认样式 (w:default="1")

        // 直接在此样式元素中定义的属性
        var directRunProperties: Attributes?         // 直接定义的字符/运行属性
        var directParagraphProperties: Attributes?   // 直接定义的段落属性
        // 可在此处添加表格属性等

        // 缓存的已解析属性 (包括继承的属性)
        var resolvedRunProperties: Attributes? = nil       // 解析后的最终运行属性
        var resolvedParagraphProperties: Attributes? = nil // 解析后的最终段落属性
    }

    private var styles: [String: StyleDefinition] = [:] // 样式ID到样式定义的映射
    private var defaultParagraphStyleId: String?       // 文档的默认段落样式ID
    private var defaultCharacterStyleId: String?       // 文档的默认字符样式ID
    
    // 从 <w:docDefaults> 解析的文档级默认属性
    private var docDefaultRunProperties: Attributes = [:]       // 文档默认运行属性
    private var docDefaultParagraphProperties: Attributes = [:] // 文档默认段落属性


    // MARK: - Initialization (初始化)
    init() {}

    // MARK: - Parsing (解析 styles.xml)
    func parseStyles(stylesFileURL: URL) throws {
        // 重置内部状态
        styles = [:]
        defaultParagraphStyleId = nil
        defaultCharacterStyleId = nil
        docDefaultRunProperties = [:]
        docDefaultParagraphProperties = [:]


        guard FileManager.default.fileExists(atPath: stylesFileURL.path) else {
            print("StyleParser: styles.xml 未在路径 \(stylesFileURL.path) 找到。将在没有文档定义样式的情况下继续。")
            // 允许继续执行；DocParser 将使用其自身的硬编码默认值。
            return
        }

        do {
            let xmlString = try String(contentsOf: stylesFileURL, encoding: .utf8)
            let xml = XMLHash.parse(xmlString) // 使用SWXMLHash解析XML

            // 1. 解析 <w:docDefaults> (文档默认值)
            let docDefaultsNode = xml["w:styles"]["w:docDefaults"]
            if docDefaultsNode.element != nil {
                // 解析默认运行属性
                if docDefaultsNode["w:rPrDefault"]["w:rPr"].element != nil {
                    docDefaultRunProperties = parseRunProperties(runPropertyXML: docDefaultsNode["w:rPrDefault"]["w:rPr"], forStyleDefinition: true)
                }
                // 解析默认段落属性
                if docDefaultsNode["w:pPrDefault"]["w:pPr"].element != nil {
                    // parseParagraphProperties 返回 (段落属性, 段落的默认运行属性)
                    // 对于 docDefaults，我们只关心段落属性部分作为 docDefaultParagraphProperties。
                    docDefaultParagraphProperties = parseParagraphProperties(paraPropertyXML: docDefaultsNode["w:pPrDefault"]["w:pPr"], forStyleDefinition: true).paragraphAttributes
                }
            }

            // 2. 解析各个 <w:style> 元素
            for styleNode in xml["w:styles"]["w:style"].all {
                guard let styleId = styleNode.attributeValue(by: "w:styleId"),          // 样式ID
                      let typeRaw = styleNode.attributeValue(by: "w:type"),             // 样式类型字符串
                      let styleType = StyleType(rawValue: typeRaw) else {               // 转换为StyleType枚举
                    continue // 跳过无效的样式定义
                }

                let name = styleNode["w:name"].attributeValue(by: "w:val")                 // 样式名称
                let basedOn = styleNode["w:basedOn"].attributeValue(by: "w:val")           // 基于的父样式ID
                let isDefaultFlag = styleNode.attributeValue(by: "w:default") == "1"       // 是否为默认样式

                var directRunProps: Attributes? = nil
                // 解析此样式直接定义的 <w:rPr> (运行属性)
                if styleNode["w:rPr"].element != nil {
                    directRunProps = parseRunProperties(runPropertyXML: styleNode["w:rPr"], forStyleDefinition: true)
                }

                var directParaProps: Attributes? = nil
                // 解析此样式直接定义的 <w:pPr> (段落属性)
                if styleNode["w:pPr"].element != nil {
                    // 对于样式定义，<w:pPr> 包含段落级别的设置。
                    // 此 <w:pPr> 内部的任何 <w:rPr> 定义了当此段落样式应用时，其内容的默认运行属性。
                    let (pAttrs, rAttrsFromPPr) = parseParagraphProperties(paraPropertyXML: styleNode["w:pPr"], forStyleDefinition: true)
                    directParaProps = pAttrs // 段落级别属性

                    // 如果这是段落样式，来自 <w:pPr><w:rPr> 的运行属性会贡献给其字符属性部分。
                    // 将 rAttrsFromPPr 与 directRunProps 合并。通常，样式上直接的 <w:rPr> 会覆盖 <w:pPr><w:rPr> 中的。
                    if styleType == .paragraph {
                        var tempRunProps = rAttrsFromPPr // 从 <w:pPr><w:rPr> 来的
                        if let drp = directRunProps {    // 从样式直接 <w:rPr> 来的
                            // 合并，让直接在 <w:style><w:rPr> 定义的优先
                            tempRunProps.merge(drp) { _, valueFromDirectStyleRPr -> Any in valueFromDirectStyleRPr }
                        }
                        directRunProps = tempRunProps.isEmpty ? nil : tempRunProps
                    }
                }
                
                let styleDef = StyleDefinition(
                    styleId: styleId,
                    type: styleType,
                    name: name,
                    basedOn: basedOn,
                    isDefault: isDefaultFlag,
                    directRunProperties: directRunProps,
                    directParagraphProperties: directParaProps
                )
                styles[styleId] = styleDef // 存储样式定义

                // 记录默认样式ID
                if isDefaultFlag {
                    if styleType == .paragraph { defaultParagraphStyleId = styleId }
                    if styleType == .character { defaultCharacterStyleId = styleId }
                }
            }
            
            // 3. 解析所有样式 (填充缓存的 resolvedRunProperties 和 resolvedParagraphProperties)
            // 这一步处理样式的继承链
            for styleId in styles.keys {
                resolveStyle(styleId: styleId)
            }

            print("StyleParser: 已从 styles.xml 解析并处理了 \(styles.count) 个样式。")
        } catch {
            print("StyleParser: 解析 styles.xml 出错: \(error)。将在没有文档定义样式的情况下继续。")
            // 出错时允许继续，但不会有来自styles.xml的样式信息
        }
    }

    // MARK: - Style Resolution and Query (样式解析与查询)
    
    /**
     * 递归地解析指定styleId的样式，合并其父样式的属性。
     * 结果存储在样式的 resolvedRunProperties 和 resolvedParagraphProperties 中。
     * - Parameter styleId: 要解析的样式ID。
     */
    private func resolveStyle(styleId: String) {
        guard var styleToResolve = styles[styleId] else { return } // 确保样式存在
        
        // 检查是否已解析，避免重复工作 (更细致的检查)
        let isParagraphStyle = (styleToResolve.type == .paragraph)
        let runResolved = (styleToResolve.resolvedRunProperties != nil)
        let paraResolved = (styleToResolve.resolvedParagraphProperties != nil)

        if isParagraphStyle && runResolved && paraResolved { return }
        if !isParagraphStyle && runResolved { return } // 字符样式只需要run属性


        var resolvedRunProps = Attributes()
        var resolvedParaProps = Attributes()
        
        // 1. 应用父样式属性 (如果存在)
        if let parentId = styleToResolve.basedOn {
            // 确保父样式已解析
            if let parentStyleDef = styles[parentId] {
                let parentIsParagraph = (parentStyleDef.type == .paragraph)
                let parentRunResolved = (parentStyleDef.resolvedRunProperties != nil)
                let parentParaResolved = (parentStyleDef.resolvedParagraphProperties != nil)

                var needsParentResolve = false
                if parentIsParagraph && (!parentRunResolved || !parentParaResolved) {
                    needsParentResolve = true
                } else if !parentIsParagraph && !parentRunResolved {
                    needsParentResolve = true
                }
                if needsParentResolve {
                     resolveStyle(styleId: parentId)
                }
            }
            
            if let parentStyle = styles[parentId] { // 重新获取，因为resolveStyle可能已更新它
                resolvedRunProps.merge(parentStyle.resolvedRunProperties ?? [:]) { _, new in new } // 合并父的运行属性
                if styleToResolve.type == .paragraph { // 段落样式才继承段落属性
                    resolvedParaProps.merge(parentStyle.resolvedParagraphProperties ?? [:]) { _, new in new }
                }
            }
        } else {
            // 没有父样式：此样式是根样式。应用文档默认值作为基础。
            resolvedRunProps.merge(docDefaultRunProperties) { _, new in new }
            if styleToResolve.type == .paragraph {
                resolvedParaProps.merge(docDefaultParagraphProperties) { _, new in new }
            }
        }

        // 2. 合并此样式直接定义的属性
        if let directRun = styleToResolve.directRunProperties {
            resolvedRunProps.merge(directRun) { _, new in new } // 当前样式的运行属性优先
        }
        if styleToResolve.type == .paragraph, let directPara = styleToResolve.directParagraphProperties {
            resolvedParaProps.merge(directPara) { _, new in new } // 当前样式的段落属性优先
        }
        
        // 缓存解析结果
        styleToResolve.resolvedRunProperties = resolvedRunProps.isEmpty ? nil : resolvedRunProps
        if styleToResolve.type == .paragraph {
            styleToResolve.resolvedParagraphProperties = resolvedParaProps.isEmpty ? nil : resolvedParaProps
        }
        styles[styleId] = styleToResolve // 更新字典中的样式定义
    }

    /**
     * 获取指定styleId的完全解析后的运行属性和段落属性。
     * - Parameter styleId: 样式ID。
     * - Returns: 一个元组，包含运行属性和段落属性。如果样式不存在或类型不匹配，则返回空字典。
     */
    func getResolvedAttributes(forStyleId styleId: String) -> (run: Attributes, paragraph: Attributes) {
        guard let style = styles[styleId] else {
            // print("StyleParser: 请求的样式ID '\(styleId)' 未找到。")
            return ([:], [:]) // 样式不存在，返回空属性
        }
        // 确保已解析 (理论上在 parseStyles 后都应已解析)
        let run = style.resolvedRunProperties ?? [:]
        let para = style.type == .paragraph ? (style.resolvedParagraphProperties ?? [:]) : [:]
        return (run, para)
    }
    
    /**
     * 获取文档的默认段落样式的属性 (运行属性和段落属性)。
     * 会优先查找标记为 default="1" 的段落样式，其次是名为 "Normal" 的样式，
     * 最后回退到 <w:docDefaults> 中定义的段落默认值。
     */
    func getDefaultParagraphStyleAttributes() -> (run: Attributes, paragraph: Attributes) {
        if let defParaId = defaultParagraphStyleId { // 查找标记为 default="1" 的段落样式
            return getResolvedAttributes(forStyleId: defParaId)
        }
        if let normalStyleId = styles.first(where: { $0.value.name == "Normal" && $0.value.type == .paragraph })?.key { // 查找名为 "Normal" 的段落样式
            return getResolvedAttributes(forStyleId: normalStyleId)
        }
        // 如果都没有，则使用从 <w:docDefaults> 解析的文档级默认段落和运行属性
        return (docDefaultRunProperties, docDefaultParagraphProperties)
    }

    /**
     * 获取文档的默认字符样式的运行属性。
     * 优先查找标记为 default="1" 的字符样式，其次是名为 "DefaultParagraphFont" 的样式 (Word中常见)，
     * 最后回退到 <w:docDefaults> 中定义的运行默认值。
     */
    func getDefaultCharacterStyleAttributes() -> Attributes {
        if let defCharId = defaultCharacterStyleId { // 查找标记为 default="1" 的字符样式
            return getResolvedAttributes(forStyleId: defCharId).run
        }
        if let defaultParaFontId = styles.first(where: { $0.value.name == "Default Paragraph Font" && $0.value.type == .character })?.key { // 查找名为 "Default Paragraph Font" 的字符样式
            return getResolvedAttributes(forStyleId: defaultParaFontId).run
        }
        // 如果都没有，则使用从 <w:docDefaults> 解析的文档级默认运行属性
        return docDefaultRunProperties
    }

    // MARK: - Property Parsing (from style definitions) (属性解析 - 用于样式定义)
    // 此处的 `forStyleDefinition` 标志可以用来调整行为，以适应样式定义XML中可能存在的细微差别
    
    /**
     * 从XML节点解析运行属性。
     * - Parameter runPropertyXML: 指向 <w:rPr> 节点的 XMLIndexer。
     * - Parameter forStyleDefinition: 是否为样式定义进行解析 (可能影响默认值或行为)。
     * - Returns: 包含解析出的运行属性的字典。
     */
    private func parseRunProperties(runPropertyXML: XMLNode, forStyleDefinition: Bool = false) -> Attributes {
        var attributes: Attributes = [:] // 初始化空属性字典
        // 初始默认值，实际默认值应由 DocxConstants 或继承链提供，这里是解析时使用的临时基准
        var fontSize = DocxConstants.defaultFontSize
        var fontNameFromDocx: String? = nil
        var isBold = false, isItalic = false, isUnderline = false, isStrikethrough = false
        var foregroundColorHex: String? = nil, highlightColorName: String? = nil
        var verticalAlign: Int = 0 // 0: 基线, 1: 上标, 2: 下标

        // 字体大小 (<w:sz w:val="半点值"> 或 <w:szCs ...>)
        if let szStr = runPropertyXML["w:sz"].attributeValue(by: "w:val") ?? runPropertyXML["w:szCs"].attributeValue(by: "w:val"),
           let sizeValHalfPoints = Double(szStr) {
            fontSize = CGFloat(sizeValHalfPoints) / 2.0 // 半点转磅
        }

        // 字体名称 (<w:rFonts w:ascii="..." w:hAnsi="..." w:eastAsia="..." w:cs="...">)
        let rFontsNode = runPropertyXML["w:rFonts"]
        fontNameFromDocx = rFontsNode.attributeValue(by: "w:ascii") ??
                           rFontsNode.attributeValue(by: "w:hAnsi") ??
                           rFontsNode.attributeValue(by: "w:eastAsia") ?? // 东亚字体
                           rFontsNode.attributeValue(by: "w:cs")        // 复杂文种字体

        // 粗体 (<w:b/> 或 <w:b w:val="0|false">), 斜体 (<w:i/> 或 <w:i w:val="0|false">)
        // val="0" 或 val="false" 表示关闭该属性，否则为开启。
        isBold = (runPropertyXML["w:b"].element != nil && runPropertyXML["w:b"].attributeValue(by: "w:val") != "0" && runPropertyXML["w:b"].attributeValue(by: "w:val") != "false") ||
                 (runPropertyXML["w:bCs"].element != nil && runPropertyXML["w:bCs"].attributeValue(by: "w:val") != "0" && runPropertyXML["w:bCs"].attributeValue(by: "w:val") != "false")
        isItalic = (runPropertyXML["w:i"].element != nil && runPropertyXML["w:i"].attributeValue(by: "w:val") != "0" && runPropertyXML["w:i"].attributeValue(by: "w:val") != "false") ||
                   (runPropertyXML["w:iCs"].element != nil && runPropertyXML["w:iCs"].attributeValue(by: "w:val") != "0" && runPropertyXML["w:iCs"].attributeValue(by: "w:val") != "false")
        
        // 下划线 (<w:u w:val="none|single|...">)
        if let uNode = runPropertyXML["w:u"].element { // 检查 <w:u> 元素是否存在
            let uVal = uNode.attribute(by: "w:val")?.text.lowercased() // 获取 w:val 属性值
            if uVal == "none" || uVal == "0" { // "none" 或 "0" 表示无下划线
                isUnderline = false
            } else { // 其他情况 (包括 "single", "double", 或仅存在<w:u/>标签) 都视为有下划线
                isUnderline = true
                // TODO: 可以根据 uVal 的具体值设置不同的 NSUnderlineStyle (如 .double)
            }
        }

        // 删除线 (<w:strike/> 或 <w:dstrike/>)
        if (runPropertyXML["w:strike"].element != nil && runPropertyXML["w:strike"].attributeValue(by: "w:val") != "0" && runPropertyXML["w:strike"].attributeValue(by: "w:val") != "false") ||
           (runPropertyXML["w:dstrike"].element != nil && runPropertyXML["w:dstrike"].attributeValue(by: "w:val") != "0" && runPropertyXML["w:dstrike"].attributeValue(by: "w:val") != "false") {
            isStrikethrough = true // 双删除线也暂时视为单删除线
        }

        // 文本颜色 (<w:color w:val="RRGGBB">), "auto" 表示默认颜色
        if let colorVal = runPropertyXML["w:color"].attributeValue(by: "w:val"), colorVal.lowercased() != "auto" {
            foregroundColorHex = colorVal
        }
        
        // 高亮颜色 (<w:highlight w:val="yellow|...">), "none" 表示无高亮
         if let highlightVal = runPropertyXML["w:highlight"].attributeValue(by: "w:val"), highlightVal.lowercased() != "none" {
             highlightColorName = highlightVal
         }

        // 垂直对齐 (上标/下标) (<w:vertAlign w:val="superscript|subscript">)
        if let vertAlignVal = runPropertyXML["w:vertAlign"].attributeValue(by: "w:val") {
            switch vertAlignVal.lowercased() {
            case "superscript": verticalAlign = 1
            case "subscript": verticalAlign = 2
            default: break // 默认为0 (基线)
            }
        }
        
        // -- 构建字体并应用到属性字典 --
        var traits: UIFontDescriptor.SymbolicTraits = [] // 字体特征 (粗体/斜体)
        if isBold { traits.insert(.traitBold) }
        if isItalic { traits.insert(.traitItalic) }

        let baseFontName = fontNameFromDocx ?? DocxConstants.defaultFontName // 如果文档未指定，使用全局默认字体名
        var finalFont: UIFont?

        // 尝试使用指定名称和大小创建字体，并应用特征
        if let baseFont = UIFont(name: baseFontName, size: fontSize) {
            if !traits.isEmpty, let fontDescriptorWithTraits = baseFont.fontDescriptor.withSymbolicTraits(traits) {
                finalFont = UIFont(descriptor: fontDescriptorWithTraits, size: fontSize)
            } else { // 如果没有特征或无法应用，使用基础字体
                finalFont = baseFont
            }
        } else { // 如果指定字体名称无效或未找到
            // print("StyleParser: 字体 '\(baseFontName)' 未找到。回退到系统字体。")
            let systemFont = UIFont.systemFont(ofSize: fontSize) // 使用系统默认字体
            if !traits.isEmpty, let fontDescriptorWithTraits = systemFont.fontDescriptor.withSymbolicTraits(traits) {
                finalFont = UIFont(descriptor: fontDescriptorWithTraits, size: fontSize)
            } else {
                finalFont = systemFont
            }
        }
        
        if let font = finalFont { attributes[.font] = font } // 设置字体属性
        
        // 设置文本颜色 (如果指定了有效的十六进制颜色)
        if let hex = foregroundColorHex, let color = UIColor(hex: hex) {
            attributes[.foregroundColor] = color
        } // 注意：如果 forStyleDefinition 为 true，不设置默认黑色，让继承链处理。
          // 如果 forStyleDefinition 为 false (用于直接格式化)，则可能需要确保有颜色（如DocParser中的逻辑）。
          // 这里作为样式解析，只记录在XML中明确指定的值。
        
        // 设置下划线和删除线
        if isUnderline { attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue }
        if isStrikethrough { attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue }
        
        // 设置高亮背景色
        if let hlName = highlightColorName, let hlColor = mapHighlightColor(hlName) {
            attributes[.backgroundColor] = hlColor
        }
        
        // 设置上标/下标
        if verticalAlign != 0 {
                let actualFontSizeForOffset = (finalFont ?? UIFont.systemFont(ofSize: fontSize)).pointSize // 获取实际应用的字号
                attributes[.baselineOffset] = (verticalAlign == 1) ? (actualFontSizeForOffset * 0.35) : -(actualFontSizeForOffset * 0.20)
                
                // 为上标/下标使用稍小字体，并保持原有特征
                if let currentBaseFont = finalFont { // 确保有有效字体
                    let targetSize = actualFontSizeForOffset * 0.75
                    if let smallerFontDescriptor = currentBaseFont.fontDescriptor.withSymbolicTraits(traits) {
                        attributes[.font] = UIFont(descriptor: smallerFontDescriptor, size: targetSize)
                    } else { // Fallback if traits can't be applied to the descriptor
                        attributes[.font] = UIFont(name: currentBaseFont.fontName, size: targetSize) ?? UIFont.systemFont(ofSize: targetSize)
                    }
                }
            }
        return attributes
    }

    /**
     * 从XML节点解析段落属性。
     * - Parameter paraPropertyXML: 指向 <w:pPr> 节点的 XMLIndexer。
     * - Parameter forStyleDefinition: 是否为样式定义进行解析。
     * - Returns: 一个元组，包含段落级属性和从此 <w:pPr> 的子 <w:rPr> 解析出的默认运行属性。
     */
    private func parseParagraphProperties(paraPropertyXML: XMLNode, forStyleDefinition: Bool = false) -> (paragraphAttributes: Attributes, runAttributesFromPPr: Attributes) {
        var pAttrs: Attributes = [:] // 用于存储段落级属性 (主要是 NSParagraphStyle)
        let pStyle = NSMutableParagraphStyle() // 创建可变段落样式对象
        // 为 NSParagraphStyle 设置一些在XML中可能不会指定或继承而来的基础默认值
        pStyle.alignment = .natural       // 自然对齐 (根据书写方向)
        pStyle.lineHeightMultiple = 1.0 // 默认单倍行距

        // 对齐方式 (<w:jc w:val="...">)
        if let alignVal = paraPropertyXML["w:jc"].attributeValue(by: "w:val") {
            switch alignVal.lowercased() {
            case "left", "start": pStyle.alignment = .left
            case "right", "end": pStyle.alignment = .right
            case "center": pStyle.alignment = .center
            case "both", "distribute", "justify": pStyle.alignment = .justified // "both", "distribute", "justify" 都视为两端对齐
            default: break // 未知值，保持默认或继承值
            }
        }

        // 缩进 (<w:ind ...>), 单位: Twips (缇), 1 Point = 20 Twips
        let twipsPerPoint: CGFloat = 20.0
        let indNode = paraPropertyXML["w:ind"]
        if indNode.element != nil {
            var baseLeftIndent: CGFloat = 0 // 如果XML未指定，则基础左缩进为0
            // 左缩进 (w:left 或 w:start)
            if let leftValStr = indNode.attributeValue(by: "w:left") ?? indNode.attributeValue(by: "w:start"),
               let val = Double(leftValStr) {
                baseLeftIndent = CGFloat(val) / twipsPerPoint
            }
            pStyle.headIndent = baseLeftIndent // 除首行外其他行的头部缩进量

            // 首行缩进 (w:firstLine) 或 悬挂缩进 (w:hanging)
            if let firstLineValStr = indNode.attributeValue(by: "w:firstLine"), // 首行额外缩进 (相对于 headIndent)
               let val = Double(firstLineValStr) {
                 pStyle.firstLineHeadIndent = baseLeftIndent + (CGFloat(val) / twipsPerPoint) // 这是相对于页面边距的绝对首行缩进
            } else if let hangingValStr = indNode.attributeValue(by: "w:hanging"),  // 悬挂缩进量
                      let val = Double(hangingValStr)  {
                 let hangingAmount = CGFloat(val) / twipsPerPoint
                 pStyle.firstLineHeadIndent = baseLeftIndent         // 首行在基础左缩进处开始
                 pStyle.headIndent = baseLeftIndent + hangingAmount  // 后续行再向右缩进悬挂量
             } else { // 如果没有指定 firstLine 或 hanging，则首行缩进与后续行相同
                 pStyle.firstLineHeadIndent = baseLeftIndent
             }
        }
        
        // 间距 (<w:spacing ...>)
        if let spacingNode = paraPropertyXML["w:spacing"].element {
            // 段前间距 (<w:before ...>)
            if let beforeStr = spacingNode.attribute(by: "w:before")?.text, let val = Double(beforeStr) {
                pStyle.paragraphSpacingBefore = CGFloat(val) / twipsPerPoint
            }
            // 段后间距 (<w:after ...>)
            if let afterStr = spacingNode.attribute(by: "w:after")?.text, let val = Double(afterStr) {
                pStyle.paragraphSpacing = CGFloat(val) / twipsPerPoint // NSParagraphStyle的paragraphSpacing指段后间距
            }
            
            // 行距 (<w:line w:val="..."> 和 <w:lineRule w:val="...">)
            // 默认行高倍数为1.0（单倍行距），最小/最大行高为0（表示不限制或由倍数决定）
            var ruleApplied = false // 标记是否已应用显式行距规则
            if let lineValStr = spacingNode.attribute(by: "w:line")?.text, let lineVal = Double(lineValStr) {
                 let lineRule = spacingNode.attribute(by: "w:lineRule")?.text.lowercased()
                 switch lineRule {
                 case "auto": // 值以行的 1/240 表示行高倍数
                      pStyle.lineHeightMultiple = CGFloat(lineVal) / 240.0
                      pStyle.minimumLineHeight = 0; pStyle.maximumLineHeight = 0 // 清除固定行高限制
                      ruleApplied = true
                 case "exact": // 值单位为 Twips，表示固定行高
                      let exactHeight = CGFloat(lineVal) / twipsPerPoint
                      pStyle.minimumLineHeight = exactHeight; pStyle.maximumLineHeight = exactHeight
                      pStyle.lineHeightMultiple = 0 // 使用固定行高时，倍数应为0或不设置
                      ruleApplied = true
                 case "atleast": // 值单位为 Twips，表示最小行高
                      pStyle.minimumLineHeight = CGFloat(lineVal) / twipsPerPoint
                      pStyle.maximumLineHeight = 0; pStyle.lineHeightMultiple = 0 // 倍数为0或不设置
                      ruleApplied = true
                 default: // 包括 lineRule 未指定（通常视为 'multiple'，lineVal是240的倍数）或 "multiple"
                      if lineRule == nil || lineRule == "multiple" { // 明确处理这两种情况
                          pStyle.lineHeightMultiple = CGFloat(lineVal) / 240.0
                          pStyle.minimumLineHeight = 0; pStyle.maximumLineHeight = 0
                          ruleApplied = true
                      }
                 }
             }
             // 如果没有应用任何显式规则，但pStyle中仍是默认值，可以保持。
             // 如果继承来的pStyle有值，而XML中没有行距设置，则继承值保持。
        }
        pAttrs[.paragraphStyle] = pStyle.copy() // 存储最终配置的NSParagraphStyle对象

        // 解析此 <w:pPr> 下的 <w:rPr>，作为此段落样式关联的默认运行属性
        var rAttrsFromPPr: Attributes = [:]
        if paraPropertyXML["w:rPr"].element != nil { // 检查是否存在 <w:pPr><w:rPr>
            rAttrsFromPPr = parseRunProperties(runPropertyXML: paraPropertyXML["w:rPr"], forStyleDefinition: forStyleDefinition)
        }
        
        return (pAttrs, rAttrsFromPPr)
    }
    
    // MARK: - Helpers (辅助函数)
    
    /**
     * 将OOXML标准高亮颜色名称映射到UIColor。
     * - Parameter value: 颜色名称字符串 (如 "yellow")。
     * - Returns: 对应的UIColor，或nil（如果名称未知）。
     */
    private func mapHighlightColor(_ value: String) -> UIColor? {
        switch value.lowercased() { // 转换为小写以便不区分大小写比较
        case "yellow": return UIColor.yellow.withAlphaComponent(0.4) // 黄色高亮，带透明度
        case "green": return UIColor.green.withAlphaComponent(0.3)
        case "red": return UIColor.red.withAlphaComponent(0.3)
        case "blue": return UIColor.blue.withAlphaComponent(0.3)
        case "cyan": return UIColor.cyan.withAlphaComponent(0.3)
        case "magenta": return UIColor.magenta.withAlphaComponent(0.3)
        case "lightgray", "lightGray": return UIColor.lightGray.withAlphaComponent(0.4) // 浅灰色
        case "darkgray", "darkGray": return UIColor.darkGray.withAlphaComponent(0.4) // 深灰色
        // ... 可以添加更多 OOXML <w:highlight w:val="..."> 的颜色映射
        default: return nil // 未知颜色名称
        }
    }
}
