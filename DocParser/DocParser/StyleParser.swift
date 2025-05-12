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
    typealias XMLNode = XMLIndexer
    typealias Attributes = [NSAttributedString.Key: Any]

    enum StyleType: String {
        case paragraph = "paragraph"
        case character = "character"
        case table = "table"        // 未在本示例中深入处理
        case numbering = "numbering"  // 未在本示例中深入处理
    }

    // 存储从XML直接解析的原子属性的键 (用于内部传递)
    private struct AtomicStyleKeys {
        // 运行属性原子标记
        static let fontName = NSAttributedString.Key("atomic.fontName")           // String
        static let fontSize = NSAttributedString.Key("atomic.fontSize")           // CGFloat (points)
        static let isBold = NSAttributedString.Key("atomic.isBold")               // Bool
        static let isItalic = NSAttributedString.Key("atomic.isItalic")           // Bool
        static let foregroundColorHex = NSAttributedString.Key("atomic.colorHex") // String
        static let underline = NSAttributedString.Key("atomic.underline")         // String (e.g., "single", "none")
        static let strikethrough = NSAttributedString.Key("atomic.strikethrough") // Bool
        static let highlightColorName = NSAttributedString.Key("atomic.highlight")// String
        static let verticalAlignment = NSAttributedString.Key("atomic.vertAlign") // String ("superscript", "subscript")
        
        // 段落属性原子标记 (用于构建 NSParagraphStyle)
        static let alignment = NSAttributedString.Key("atomic.para.alignment")                  // NSTextAlignment.RawValue
        static let paragraphSpacingBefore = NSAttributedString.Key("atomic.para.spacingBefore") // CGFloat (points)
        static let paragraphSpacingAfter = NSAttributedString.Key("atomic.para.spacingAfter")   // CGFloat (points)
        static let lineHeightMultiple = NSAttributedString.Key("atomic.para.lineHeightMultiple")// CGFloat
        static let minimumLineHeight = NSAttributedString.Key("atomic.para.minLineHeight")      // CGFloat (points)
        static let maximumLineHeight = NSAttributedString.Key("atomic.para.maxLineHeight")      // CGFloat (points)
        static let lineSpacing = NSAttributedString.Key("atomic.para.lineSpacing")            // CGFloat (points)
        static let headIndent = NSAttributedString.Key("atomic.para.headIndent")              // CGFloat (points)
        static let firstLineHeadIndent = NSAttributedString.Key("atomic.para.firstLineHeadIndent")// CGFloat (points)
        // 可以添加更多原子段落属性键，如 tailIndent, tabStops 等
        
        static let themeColorName = NSAttributedString.Key("atomic.theme.colorName")
        static let themeColorTint = NSAttributedString.Key("atomic.theme.colorTint")
        static let themeColorShade = NSAttributedString.Key("atomic.theme.colorShade")
        // 对于背景/底纹
        static let themeFillName = NSAttributedString.Key("atomic.theme.fillName")
        static let themeFillTint = NSAttributedString.Key("atomic.theme.fillTint")
        static let themeFillShade = NSAttributedString.Key("atomic.theme.fillShade")
        
        // << 新增/确认段落底纹原子键 >>
          static let paraBackgroundColorHex = NSAttributedString.Key("atomic.para.bgColorHex")
          static let paraBackgroundThemeColorName = NSAttributedString.Key("atomic.para.bgThemeColorName")
          static let paraBackgroundThemeColorTint = NSAttributedString.Key("atomic.para.bgThemeColorTint")
          static let paraBackgroundThemeColorShade = NSAttributedString.Key("atomic.para.bgThemeColorShade")
        
        
    }

    struct StyleDefinition {
        let styleId: String
        let type: StyleType
        let name: String?
        let basedOn: String?
        let isDefault: Bool

        // 存储从XML直接解析的“原子”属性，而不是已构建的UI对象
        var directAtomicRunProperties: Attributes = [:]
        var directAtomicParagraphProperties: Attributes = [:] // 对于段落样式，这些原子属性将用于配置NSParagraphStyle

        // 缓存的已解析属性 (这些将包含构建好的UIFont, NSParagraphStyle等)
        var resolvedRunProperties: Attributes = [:]
        var resolvedParagraphProperties: Attributes = [:]
        var isBeingResolved: Bool = false
        var hasBeenFullyResolved: Bool = false
    }

    private var styles: [String: StyleDefinition] = [:]
    private var defaultParagraphStyleId: String?
    private var defaultCharacterStyleId: String?
    
    // 这些将存储已构建的 NSAttributedString.Key 属性 (如 .font, .paragraphStyle)
    private var docDefaultRunProperties: Attributes = [:]
    private var docDefaultParagraphProperties: Attributes = [:]

    init() {
        // 初始化文档默认段落属性为一个基础的 NSParagraphStyle
        let baseDefaultPStyle = NSMutableParagraphStyle()
        baseDefaultPStyle.alignment = .natural
        baseDefaultPStyle.lineHeightMultiple = 1.0
        docDefaultParagraphProperties[.paragraphStyle] = baseDefaultPStyle.copy()
        // docDefaultRunProperties 初始为空，将从 styles.xml 或硬编码常量填充
    }

    func parseStyles(stylesFileURL: URL) throws {
            // 重置内部状态
            styles = [:]
            defaultParagraphStyleId = nil
            defaultCharacterStyleId = nil
            docDefaultRunProperties = [:]
            docDefaultParagraphProperties = [:]

            // --- 初始化 docDefaults 的基础值 ---
            // 确保即使文件未找到或解析失败，docDefaults 也有一个可用的基础 NSParagraphStyle
            let baseDefaultPStyleForFallback = NSMutableParagraphStyle()
            baseDefaultPStyleForFallback.alignment = .natural
            baseDefaultPStyleForFallback.lineHeightMultiple = 1.0
            let fallbackParaAttrs: Attributes = [.paragraphStyle: baseDefaultPStyleForFallback.copy()]
            docDefaultParagraphProperties = fallbackParaAttrs // 先设置一个最基础的

            // 同样，为 docDefaultRunProperties 设置一个基础字体，以防 styles.xml 无定义或解析失败
            // 实际值将在下面从 styles.xml 的 <docDefaults> 中尝试覆盖
            docDefaultRunProperties[.font] = UIFont(name: DocxConstants.defaultFontName, size: DocxConstants.defaultFontSize) ?? UIFont.systemFont(ofSize: DocxConstants.defaultFontSize)


            guard FileManager.default.fileExists(atPath: stylesFileURL.path) else {
                print("StyleParser: styles.xml 未在路径 \(stylesFileURL.path) 找到。将使用内部基础默认样式。")
                // docDefaultParagraphProperties 和 docDefaultRunProperties 已有基础值，所以直接返回
                return
            }

            do {
                let xmlString = try String(contentsOf: stylesFileURL, encoding: .utf8)
                let xml = XMLHash.parse(xmlString)

                // 1. 解析 <w:docDefaults> (文档默认值)，这些会覆盖上面设置的基础默认值
                let docDefaultsNode = xml["w:styles"]["w:docDefaults"]
                if docDefaultsNode.element != nil {
                    if docDefaultsNode["w:rPrDefault"]["w:rPr"].element != nil {
                        let atomicDefaults = parseAtomicRunProperties(from: docDefaultsNode["w:rPrDefault"]["w:rPr"])
                        // 基于这些原子属性和“无基础”来构建完整的运行属性
                        docDefaultRunProperties = buildRunAttributes(from: atomicDefaults, basedOn: [:])
                    }
                    // else: 如果XML中没有 <w:rPrDefault>, docDefaultRunProperties 保持 init 中设置的基础字体

                    if docDefaultsNode["w:pPrDefault"]["w:pPr"].element != nil {
                           let pPrDefaultNode = docDefaultsNode["w:pPrDefault"]["w:pPr"]
                           let (atomicParaDefaults, _) = parseAtomicParagraphProperties(from: pPrDefaultNode) // 获取原子段落属性
                           
                           // 构建文档默认段落属性（包括 NSParagraphStyle）
                           docDefaultParagraphProperties = buildParagraphAttributes(from: atomicParaDefaults, basedOn: [:]) // 基础是空的

                           // << 新增：从文档默认 pPrDefault 中提取并设置底纹 >>
                           // buildParagraphAttributes 已经将原子底纹信息放入了 ExtendedDocxStyleAttributes 键中
                           // 所以 docDefaultParagraphProperties 此时可能已包含这些键。
                           // 如果你想在这里直接设置一个 .backgroundColor 到 docDefaultParagraphProperties (如果它是固定的十六进制颜色)，
                           // 你需要额外逻辑。但通常，让 DocParser 处理更好。
                           //
                           // 例如，如果想让 docDefaultParagraphProperties 直接包含一个 UIColor for background:
                           // var defaultParaBgColor: UIColor?
                           // if let hex = atomicParaDefaults[AtomicStyleKeys.paraBackgroundColorHex] as? String, let color = UIColor(hex: hex) {
                           //     defaultParaBgColor = color
                           // } else if let themeName = atomicParaDefaults[AtomicStyleKeys.paraBackgroundThemeColorName] as? String {
                           //      // 这里 StyleParser 通常不能直接访问 DocParser 的 themeManager
                           //      // 所以最好还是传递指令
                           // }
                           // if let bgColor = defaultParaBgColor {
                           //     docDefaultParagraphProperties[.backgroundColor] = bgColor // 注意：这会与运行的 .backgroundColor 冲突
                           // }
                           // 更好的做法是让 DocParser 从 ExtendedDocxStyleAttributes 中读取并应用。
                           // 所以 buildParagraphAttributes 的行为是正确的，它只是传递指令。
                       }
                    // else: 如果XML中没有 <w:pPrDefault>, docDefaultParagraphProperties 保持 init 中设置的基础 NSParagraphStyle
                }
                // print("StyleParser: Post-XML docDefaultRunProperties: \(docDefaultRunProperties.keys)")
                // print("StyleParser: Post-XML docDefaultParagraphProperties: \(docDefaultParagraphProperties)")


                // 2. 解析各个 <w:style> 元素，存储其直接定义的“原子”属性
                for styleNode in xml["w:styles"]["w:style"].all {
                    guard let styleId = styleNode.attributeValue(by: "w:styleId"),
                          let typeRaw = styleNode.attributeValue(by: "w:type"),
                          let styleType = StyleType(rawValue: typeRaw) else {
                        continue
                    }

                    let name = styleNode["w:name"].attributeValue(by: "w:val")
                    let basedOn = styleNode["w:basedOn"].attributeValue(by: "w:val")
                    let isDefaultFlag = styleNode.attributeValue(by: "w:default") == "1"

                    var styleDirectAtomicRunProps = Attributes()      // 用于存储当前样式直接定义的原子运行属性
                    var styleDirectAtomicParaAtomsForDef = Attributes() // 用于存储当前样式直接定义的原子段落属性

                    // 从 <w:style><w:pPr> 解析原子段落属性，和其内部 <w:rPr> 的原子运行属性
                    if styleNode["w:pPr"].element != nil {
                        // parseAtomicParagraphProperties 返回 (paragraphAtoms: Attributes, runAtomsFromPPr: Attributes)
                        let (pAtomsFromPPrNode, rAtomsFromInnerPPr) = parseAtomicParagraphProperties(from: styleNode["w:pPr"])
                        
                        // **这里是之前报错的地方，确保正确赋值**
                        styleDirectAtomicParaAtomsForDef = pAtomsFromPPrNode // pAtomsFromPPrNode 是 Attributes 类型
                        
                        // 原子运行属性从 <w:pPr><w:rPr> 来的，作为基础（优先级低）
                        styleDirectAtomicRunProps.merge(rAtomsFromInnerPPr) { _, new in new }
                    }
                    
                    // 从 <w:style><w:rPr> 解析原子运行属性
                    if styleNode["w:rPr"].element != nil {
                        let rAtomsFromStyleRPr = parseAtomicRunProperties(from: styleNode["w:rPr"])
                        // 顶层<rPr>的原子属性覆盖来自 <pPr><w:rPr> 的
                        styleDirectAtomicRunProps.merge(rAtomsFromStyleRPr) { _, new in new }
                    }
                    
                    let styleDef = StyleDefinition(
                        styleId: styleId, type: styleType, name: name, basedOn: basedOn, isDefault: isDefaultFlag,
                        directAtomicRunProperties: styleDirectAtomicRunProps,         // 存原子运行属性
                        directAtomicParagraphProperties: styleDirectAtomicParaAtomsForDef // 存原子段落属性
                    )
                    styles[styleId] = styleDef

                    if isDefaultFlag {
                        if styleType == .paragraph { defaultParagraphStyleId = styleId }
                        if styleType == .character { defaultCharacterStyleId = styleId }
                    }
                }
                
                // 3. 解析所有样式的继承链 (填充 StyleDefinition 中的 resolvedRunProperties 和 resolvedParagraphProperties)
                for styleId in styles.keys {
                    // resolveAndGetStyleAttributes 会递归处理并缓存结果到 StyleDefinition 实例中
                    _ = resolveAndGetStyleAttributes(styleId: styleId, visitedInPath: [])
                }
                // print("StyleParser: Parsed and resolved \(styles.count) styles.")

            } catch {
                print("StyleParser: 解析 styles.xml 出错: \(error)。将使用内部基础默认样式。")
                // 确保即使 styles.xml 解析出错，docDefaults 仍然有基础值 (已在方法开头和 init 中处理)
            }
        }
    
    private func resolveAndGetStyleAttributes(styleId: String, visitedInPath: Set<String>) -> (run: Attributes, paragraph: Attributes) {
        if visitedInPath.contains(styleId) {
            // print("StyleParser resolve: Circular dependency for style '\(styleId)'. Returning doc defaults.")
            return (docDefaultRunProperties, docDefaultParagraphProperties)
        }
        guard var styleDef = styles[styleId] else {
            // print("StyleParser resolve: StyleID '\(styleId)' not found. Returning doc defaults.")
            return (docDefaultRunProperties, docDefaultParagraphProperties)
        }

        if styleDef.hasBeenFullyResolved {
            return (styleDef.resolvedRunProperties, styleDef.resolvedParagraphProperties)
        }
        
        styleDef.isBeingResolved = true
        styles[styleId] = styleDef // Update dictionary

        var currentPathWithSelf = visitedInPath
        currentPathWithSelf.insert(styleId)

        var baseRunAttrs = docDefaultRunProperties
        var baseParaAttrs = docDefaultParagraphProperties // 包含基础 NSParagraphStyle

        if let parentId = styleDef.basedOn {
            let (parentRun, parentPara) = resolveAndGetStyleAttributes(styleId: parentId, visitedInPath: currentPathWithSelf)
            baseRunAttrs = parentRun
            if styleDef.type == .paragraph {
                baseParaAttrs = parentPara
            }
        }

        // 合并运行属性：将当前样式直接定义的原子运行属性应用到继承来的基础上
        let finalRunAttrs = buildRunAttributes(from: styleDef.directAtomicRunProperties, basedOn: baseRunAttrs)
        
        // 合并段落属性：将当前样式直接定义的原子段落属性应用到继承来的NSParagraphStyle上
        var finalParaAttrs = baseParaAttrs // 包含从父或文档默认继承的 NSParagraphStyle
        if styleDef.type == .paragraph {
            // buildParagraphAttributes 会获取 baseParaAttrs 中的 .paragraphStyle (或新建)，
            // 然后应用 styleDef.directAtomicParagraphProperties 中的原子属性来修改它。
            finalParaAttrs = buildParagraphAttributes(from: styleDef.directAtomicParagraphProperties, basedOn: baseParaAttrs)
        }
        
        styleDef.resolvedRunProperties = finalRunAttrs
        styleDef.resolvedParagraphProperties = finalParaAttrs
        styleDef.hasBeenFullyResolved = true
        styleDef.isBeingResolved = false
        styles[styleId] = styleDef
        
//        // --- 调试打印特定样式 ---
//         if styleId == "000013" || styleId == "000001" || styleId == defaultParagraphStyleId {
//             print("---- StyleParser: Resolved Style ID '\(styleId)' (\(styleDef.name ?? "NoName")) ----")
//             print("  BasedOn: \(styleDef.basedOn ?? "nil"), IsDefault: \(styleDef.isDefault)")
//             print("  Direct Atomic Run: \(styleDef.directAtomicRunProperties)")
//             print("  Direct Atomic Para: \(styleDef.directAtomicParagraphProperties)")
//             print("  RESOLVED Run Attributes: \(finalRunAttrs.keys)")
//             if let font = finalRunAttrs[.font] as? UIFont {
//                 print("    Font: \(font.fontName), Size: \(font.pointSize), Bold: \(font.fontDescriptor.symbolicTraits.contains(.traitBold))")
//             }
//             if let color = finalRunAttrs[.foregroundColor] { print("    Color: \(color)") }
//             print("  RESOLVED Paragraph Attributes: \(finalParaAttrs.keys)")
//             if let pStyle = finalParaAttrs[.paragraphStyle] as? NSParagraphStyle {
//                 print("    NSParagraphStyle - Alignment: \(pStyle.alignment.rawValue)")
//                 print("    NSParagraphStyle - SpacingBefore: \(pStyle.paragraphSpacingBefore)")
//                 print("    NSParagraphStyle - SpacingAfter: \(pStyle.paragraphSpacing)")
//             }
//             print("------------------------------------")
//         }

        return (finalRunAttrs, finalParaAttrs)
    }
    
    // 公开获取接口
    func getResolvedAttributes(forStyleId styleId: String) -> (run: Attributes, paragraph: Attributes) {
        return resolveAndGetStyleAttributes(styleId: styleId, visitedInPath: [])
    }
    
    func getDefaultParagraphStyleAttributes() -> (run: Attributes, paragraph: Attributes) {
        var styleIdToUse: String? = nil
        if let defParaId = defaultParagraphStyleId { // 优先使用 w:default="1" 的段落样式
            styleIdToUse = defParaId
        } else if let normalStyleId = styles.first(where: { $0.value.name == "Normal" && $0.value.type == .paragraph })?.key { // 其次是名为 "Normal" 的
            styleIdToUse = normalStyleId
        }

        if let sid = styleIdToUse {
            return getResolvedAttributes(forStyleId: sid)
        }
        // 如果都找不到，返回文档级默认
        return (docDefaultRunProperties, docDefaultParagraphProperties)
    }

    func getDefaultCharacterStyleAttributes() -> Attributes {
        var styleIdToUse: String? = nil
        if let defCharId = defaultCharacterStyleId {
            styleIdToUse = defCharId
        } else if let defaultParaFontId = styles.first(where: { $0.value.name == "Default Paragraph Font" && $0.value.type == .character })?.key {
            styleIdToUse = defaultParaFontId
        }

        if let sid = styleIdToUse {
            return getResolvedAttributes(forStyleId: sid).run
        }
        return docDefaultRunProperties
    }

    // MARK: - Atomic Property Parsing and Building
    
    // 从 <w:rPr> 解析原子运行属性
    private func parseAtomicRunProperties(from runPropertyXML: XMLNode) -> Attributes {
        var atoms: Attributes = [:]

        if let szStr = runPropertyXML["w:sz"].attributeValue(by: "w:val") ?? runPropertyXML["w:szCs"].attributeValue(by: "w:val"),
           let sizeValHalfPoints = Double(szStr) {
            atoms[AtomicStyleKeys.fontSize] = CGFloat(sizeValHalfPoints) / 2.0
        }

        let rFontsNode = runPropertyXML["w:rFonts"]
        if rFontsNode.element != nil {
            let fontName = rFontsNode.attributeValue(by: "w:ascii") ??
                           rFontsNode.attributeValue(by: "w:hAnsi") ??
                           rFontsNode.attributeValue(by: "w:eastAsia") ??
                           rFontsNode.attributeValue(by: "w:cs")
            if let fn = fontName, !fn.isEmpty { atoms[AtomicStyleKeys.fontName] = fn }
        }

        if runPropertyXML["w:b"].element != nil {
            atoms[AtomicStyleKeys.isBold] = runPropertyXML["w:b"].attributeValue(by: "w:val") != "0" && runPropertyXML["w:b"].attributeValue(by: "w:val") != "false"
        } else if runPropertyXML["w:bCs"].element != nil {
             atoms[AtomicStyleKeys.isBold] = runPropertyXML["w:bCs"].attributeValue(by: "w:val") != "0" && runPropertyXML["w:bCs"].attributeValue(by: "w:val") != "false"
        }
        
        if runPropertyXML["w:i"].element != nil {
            atoms[AtomicStyleKeys.isItalic] = runPropertyXML["w:i"].attributeValue(by: "w:val") != "0" && runPropertyXML["w:i"].attributeValue(by: "w:val") != "false"
        } else if runPropertyXML["w:iCs"].element != nil {
            atoms[AtomicStyleKeys.isItalic] = runPropertyXML["w:iCs"].attributeValue(by: "w:val") != "0" && runPropertyXML["w:iCs"].attributeValue(by: "w:val") != "false"
        }
        
        if let uNode = runPropertyXML["w:u"].element {
            let uVal = uNode.attribute(by: "w:val")?.text.lowercased()
            atoms[AtomicStyleKeys.underline] = uVal ?? "single" // 如果只有<w:u/>，默认为single
        }

        var strike = false
        if runPropertyXML["w:strike"].element != nil {
             strike = runPropertyXML["w:strike"].attributeValue(by: "w:val") != "0" && runPropertyXML["w:strike"].attributeValue(by: "w:val") != "false"
        }
        if !strike && runPropertyXML["w:dstrike"].element != nil {
             strike = runPropertyXML["w:dstrike"].attributeValue(by: "w:val") != "0" && runPropertyXML["w:dstrike"].attributeValue(by: "w:val") != "false"
        }
        if strike { atoms[AtomicStyleKeys.strikethrough] = true }

        if let colorNode = runPropertyXML["w:color"].element {
            if let hexVal = colorNode.attribute(by: "w:val")?.text, hexVal.lowercased() != "auto" {
                atoms[AtomicStyleKeys.foregroundColorHex] = hexVal // 存储直接的十六进制
            }
            if let themeColor = colorNode.attribute(by: "w:themeColor")?.text {
                atoms[AtomicStyleKeys.themeColorName] = themeColor // 存储主题颜色名称
                if let tint = colorNode.attribute(by: "w:themeTint")?.text {
                    atoms[AtomicStyleKeys.themeColorTint] = tint
                }
                if let shade = colorNode.attribute(by: "w:themeShade")?.text {
                    atoms[AtomicStyleKeys.themeColorShade] = shade
                }
            }
            // "auto" 通常意味着不在此级别定义，而是继承或使用默认，所以不特别存 "auto"
        }
        
         if let highlightVal = runPropertyXML["w:highlight"].attributeValue(by: "w:val"), highlightVal.lowercased() != "none" {
             atoms[AtomicStyleKeys.highlightColorName] = highlightVal
         }

        if let vertAlignValText = runPropertyXML["w:vertAlign"].attributeValue(by: "w:val") {
            atoms[AtomicStyleKeys.verticalAlignment] = vertAlignValText.lowercased()
        }
        return atoms
    }
    
    // 从 <w:pPr> 解析原子段落属性 (用于构建 NSParagraphStyle) 和其内部 <w:rPr> 的原子运行属性
    private func parseAtomicParagraphProperties(from paraPropertyXML: XMLNode) -> (paragraphAtoms: Attributes, runAtomsFromPPr: Attributes) {
        var pAtoms: Attributes = [:]

        if let alignVal = paraPropertyXML["w:jc"].attributeValue(by: "w:val") {
            var alignmentValue: Int?
            switch alignVal.lowercased() {
            case "left", "start": alignmentValue = NSTextAlignment.left.rawValue
            case "right", "end": alignmentValue = NSTextAlignment.right.rawValue
            case "center": alignmentValue = NSTextAlignment.center.rawValue
            case "both", "distribute", "justify": alignmentValue = NSTextAlignment.justified.rawValue
            default: break
            }
            if let alignRaw = alignmentValue { pAtoms[AtomicStyleKeys.alignment] = alignRaw }
        }

        let twipsPerPoint: CGFloat = 20.0
        let indNode = paraPropertyXML["w:ind"]
        if indNode.element != nil {
            var baseHeadIndentPts: CGFloat?
            if let leftValStr = indNode.attributeValue(by: "w:left") ?? indNode.attributeValue(by: "w:start"),
               let val = Double(leftValStr) {
                baseHeadIndentPts = CGFloat(val) / twipsPerPoint
                pAtoms[AtomicStyleKeys.headIndent] = baseHeadIndentPts
            }

            var firstLineIndentPts: CGFloat?
            if let firstLineValStr = indNode.attributeValue(by: "w:firstLine"), let val = Double(firstLineValStr) {
                 firstLineIndentPts = CGFloat(val) / twipsPerPoint
            } else if let hangingValStr = indNode.attributeValue(by: "w:hanging"), let val = Double(hangingValStr)  {
                 let hangingAmountPts = CGFloat(val) / twipsPerPoint
                 firstLineIndentPts = baseHeadIndentPts ?? 0
                 // 对于悬挂，实际的 headIndent (非首行) 是 base + hanging
                 pAtoms[AtomicStyleKeys.headIndent] = (baseHeadIndentPts ?? 0) + hangingAmountPts
            }
            if let flIndent = firstLineIndentPts {
                pAtoms[AtomicStyleKeys.firstLineHeadIndent] = flIndent
            } else if baseHeadIndentPts != nil { // 如果有 headIndent 但没有 firstLine/hanging
                pAtoms[AtomicStyleKeys.firstLineHeadIndent] = baseHeadIndentPts
            }
        }
        
        if let spacingNode = paraPropertyXML["w:spacing"].element {
            if let beforeStr = spacingNode.attribute(by: "w:before")?.text, let val = Double(beforeStr) {
                pAtoms[AtomicStyleKeys.paragraphSpacingBefore] = CGFloat(val) / twipsPerPoint
            }
            if let afterStr = spacingNode.attribute(by: "w:after")?.text, let val = Double(afterStr) {
                pAtoms[AtomicStyleKeys.paragraphSpacingAfter] = CGFloat(val) / twipsPerPoint
            }
            
            if let lineValStr = spacingNode.attribute(by: "w:line")?.text, let lineVal = Double(lineValStr) {
                 let lineRule = spacingNode.attribute(by: "w:lineRule")?.text.lowercased()
                 switch lineRule {
                 case "auto":
                      pAtoms[AtomicStyleKeys.lineHeightMultiple] = CGFloat(lineVal) / 240.0
                      pAtoms[AtomicStyleKeys.minimumLineHeight] = 0.0
                      pAtoms[AtomicStyleKeys.maximumLineHeight] = 0.0
                 case "exact":
                      let exactHeight = CGFloat(lineVal) / twipsPerPoint
                      pAtoms[AtomicStyleKeys.minimumLineHeight] = exactHeight
                      pAtoms[AtomicStyleKeys.maximumLineHeight] = exactHeight
                      pAtoms[AtomicStyleKeys.lineHeightMultiple] = 0.0
                 case "atleast":
                      pAtoms[AtomicStyleKeys.minimumLineHeight] = CGFloat(lineVal) / twipsPerPoint
                      pAtoms[AtomicStyleKeys.maximumLineHeight] = 0.0
                      pAtoms[AtomicStyleKeys.lineHeightMultiple] = 0.0
                 default:
                      if lineRule == nil || lineRule == "multiple" {
                          pAtoms[AtomicStyleKeys.lineHeightMultiple] = CGFloat(lineVal) / 240.0
                          pAtoms[AtomicStyleKeys.minimumLineHeight] = 0.0
                          pAtoms[AtomicStyleKeys.maximumLineHeight] = 0.0
                      }
                 }
             }
             // w:lineSpacing 也可以在这里解析，如果需要的话
        }
        
        // << 新增：解析段落底纹 <w:shd> >>
           let shdNode = paraPropertyXML["w:shd"]
           if shdNode.element != nil {
               if let fillHex = shdNode.attributeValue(by: "w:fill"), fillHex.lowercased() != "auto" {
                   pAtoms[AtomicStyleKeys.paraBackgroundColorHex] = fillHex
               }
               if let themeFill = shdNode.attributeValue(by: "w:themeFill") {
                   pAtoms[AtomicStyleKeys.paraBackgroundThemeColorName] = themeFill
                   if let tint = shdNode.attributeValue(by: "w:themeFillTint") {
                       pAtoms[AtomicStyleKeys.paraBackgroundThemeColorTint] = tint
                   }
                   if let shade = shdNode.attributeValue(by: "w:themeFillShade") {
                       pAtoms[AtomicStyleKeys.paraBackgroundThemeColorShade] = shade
                   }
               }
               // 注意：w:val (预定义颜色名称) 在 <w:shd> 中也可能出现，但这里优先处理 fill 和 themeFill
           }
           // << 段落底纹解析结束 >>

        var rAtomsFromPPr: Attributes = [:]
        if paraPropertyXML["w:rPr"].element != nil {
            rAtomsFromPPr = parseAtomicRunProperties(from: paraPropertyXML["w:rPr"])
        }
        
        return (pAtoms, rAtomsFromPPr)
    }

    // 构建完整的运行属性 (如UIFont, UIColor) 从原子属性和基础属性
    private func buildRunAttributes(from atoms: Attributes, basedOn base: Attributes) -> Attributes {
        var finalAttrs = base // 从基础属性开始 (可能已包含 .font, .foregroundColor 等)

        // 获取基础字体信息
        var baseFont = base[.font] as? UIFont
        var currentFontName = baseFont?.fontName
        var currentFontSize = baseFont?.pointSize
        var currentTraits = baseFont?.fontDescriptor.symbolicTraits ?? []

        // 应用原子属性中的字体名和大小来覆盖基础
        if let nameAtom = atoms[AtomicStyleKeys.fontName] as? String { currentFontName = nameAtom }
        if let sizeAtom = atoms[AtomicStyleKeys.fontSize] as? CGFloat { currentFontSize = sizeAtom }

        // 应用原子属性中的粗体/斜体标记来修改特性
        if let boldAtom = atoms[AtomicStyleKeys.isBold] as? Bool {
            if boldAtom { currentTraits.insert(.traitBold) } else { currentTraits.remove(.traitBold) }
        }
        if let italicAtom = atoms[AtomicStyleKeys.isItalic] as? Bool {
            if italicAtom { currentTraits.insert(.traitItalic) } else { currentTraits.remove(.traitItalic) }
        }
        
        // 如果字体名称、大小或特性被指定或改变，或者没有基础字体，则构建/更新字体
        let finalFontName = currentFontName ?? DocxConstants.defaultFontName
        let finalFontSize = currentFontSize ?? DocxConstants.defaultFontSize
        
        var needsFontUpdate = false
        if baseFont == nil { needsFontUpdate = true }
        if let bf = baseFont {
            if bf.fontName != finalFontName || bf.pointSize != finalFontSize || bf.fontDescriptor.symbolicTraits != currentTraits {
                needsFontUpdate = true
            }
        } else { // baseFont is nil, but we might have name/size/traits from atoms
             if currentFontName != nil || currentFontSize != nil || !currentTraits.isEmpty {
                 needsFontUpdate = true
             }
        }


        if needsFontUpdate {
            var fontToUse: UIFont?
            if let tryFont = UIFont(name: finalFontName, size: finalFontSize) {
                if !currentTraits.isEmpty, let descWithTraits = tryFont.fontDescriptor.withSymbolicTraits(currentTraits) {
                    fontToUse = UIFont(descriptor: descWithTraits, size: finalFontSize)
                } else {
                    fontToUse = tryFont // 使用无额外特性或无法应用特性的字体
                }
            } else { // 字体名无效，回退到系统字体
                let systemFont = UIFont.systemFont(ofSize: finalFontSize)
                if !currentTraits.isEmpty, let descWithTraits = systemFont.fontDescriptor.withSymbolicTraits(currentTraits) {
                    fontToUse = UIFont(descriptor: descWithTraits, size: finalFontSize)
                } else {
                    fontToUse = systemFont
                }
            }
            if let ff = fontToUse { finalAttrs[.font] = ff }
        }

        // 应用颜色
        // 1. 如果原子属性中有直接的十六进制颜色，它优先
          if let hexAtom = atoms[AtomicStyleKeys.foregroundColorHex] as? String {
              if let color = UIColor(hex: hexAtom) { // StyleParser 可以尝试解析 hex
                  finalAttrs[.foregroundColor] = color
                  // 清除可能从 base 继承的主题颜色指令，因为 hex 优先
                  finalAttrs.removeValue(forKey: ExtendedDocxStyleAttributes.themeColorName)
                  finalAttrs.removeValue(forKey: ExtendedDocxStyleAttributes.themeColorTint)
                  finalAttrs.removeValue(forKey: ExtendedDocxStyleAttributes.themeColorShade)
              }
          }
          // 2. 如果原子属性中有主题颜色指令，传递它们 (会覆盖 base 中的同类指令)
          //    这些会通过 ExtendedDocxStyleAttributes 键传递给 DocParser
          else if let themeNameAtom = atoms[AtomicStyleKeys.themeColorName] as? String {
              finalAttrs[ExtendedDocxStyleAttributes.themeColorName] = themeNameAtom
              if let tintAtom = atoms[AtomicStyleKeys.themeColorTint] as? String {
                  finalAttrs[ExtendedDocxStyleAttributes.themeColorTint] = tintAtom
              } else {
                  finalAttrs.removeValue(forKey: ExtendedDocxStyleAttributes.themeColorTint) // 清除 base 中的
              }
              if let shadeAtom = atoms[AtomicStyleKeys.themeColorShade] as? String {
                  finalAttrs[ExtendedDocxStyleAttributes.themeColorShade] = shadeAtom
              } else {
                  finalAttrs.removeValue(forKey: ExtendedDocxStyleAttributes.themeColorShade) // 清除 base 中的
              }
              // 清除可能从 base 继承的直接 .foregroundColor 和 .foregroundColorHex，因为主题指令优先于继承的 hex
              if base[AtomicStyleKeys.themeColorName] == nil { // 仅当 base 中没有主题颜色时才清除
                   finalAttrs.removeValue(forKey: .foregroundColor)
                   finalAttrs.removeValue(forKey: ExtendedDocxStyleAttributes.foregroundColorHex)
              }
          }
          // 如果 atoms 中既没有 hex 也没有 theme，则 finalAttrs 会保留 base 中的颜色信息（可能是已解析的 .foregroundColor 或其他主题指令）
        

        // 应用下划线
        if let underlineAtom = atoms[AtomicStyleKeys.underline] as? String {
            if underlineAtom.lowercased() != "none" {
                // TODO: 根据 underlineAtom 的具体值 (e.g., "single", "double") 设置 NSUnderlineStyle
                finalAttrs[.underlineStyle] = NSUnderlineStyle.single.rawValue
            } else {
                finalAttrs.removeValue(forKey: .underlineStyle)
            }
        }
        // 应用删除线
        if let strikethroughAtom = atoms[AtomicStyleKeys.strikethrough] as? Bool {
            if strikethroughAtom { finalAttrs[.strikethroughStyle] = NSUnderlineStyle.single.rawValue }
            else { finalAttrs.removeValue(forKey: .strikethroughStyle) }
        }
        // 应用高亮
        if let highlightNameAtom = atoms[AtomicStyleKeys.highlightColorName] as? String,
           let hlColor = mapHighlightColor(highlightNameAtom) {
            finalAttrs[.backgroundColor] = hlColor
        } else if atoms[AtomicStyleKeys.highlightColorName] != nil { // "none" or invalid name
            finalAttrs.removeValue(forKey: .backgroundColor)
        }
        
        // 垂直对齐 (上标/下标) - 这个由 DocParser.parseRunPropertiesFromNode 处理最终效果 (调整字号和基线)
        // StyleParser 只传递原子标记
        if let vaAtom = atoms[AtomicStyleKeys.verticalAlignment] as? String {
            finalAttrs[AtomicStyleKeys.verticalAlignment] = vaAtom // 传递原子值给DocParser
        }

        return finalAttrs
    }

    // 构建完整的段落属性 (NSParagraphStyle) 从原子属性和基础属性
    private func buildParagraphAttributes(from atoms: Attributes, basedOn base: Attributes) -> Attributes {
        var finalAttrs = base // 通常 base 包含一个 .paragraphStyle
        
        // 获取基础的 NSParagraphStyle，如果不存在则新建一个
        var pStyleToModify = (base[.paragraphStyle] as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle
        if pStyleToModify == nil {
            pStyleToModify = NSMutableParagraphStyle()
            pStyleToModify!.alignment = .natural
            pStyleToModify!.lineHeightMultiple = 1.0
            // print("StyleParser buildParagraphAttributes: Created new NSMutableParagraphStyle as base.")
        }
        
        // 将当前样式直接定义的原子段落属性应用到 pStyleToModify 上
        if let alignmentRaw = atoms[AtomicStyleKeys.alignment] as? Int,
           let alignment = NSTextAlignment(rawValue: alignmentRaw) {
            pStyleToModify!.alignment = alignment
        }
        if let spacingBefore = atoms[AtomicStyleKeys.paragraphSpacingBefore] as? CGFloat {
            pStyleToModify!.paragraphSpacingBefore = spacingBefore
        }
        if let spacingAfter = atoms[AtomicStyleKeys.paragraphSpacingAfter] as? CGFloat {
            pStyleToModify!.paragraphSpacing = spacingAfter
        }
        if let lineHeightMultiple = atoms[AtomicStyleKeys.lineHeightMultiple] as? CGFloat {
            pStyleToModify!.lineHeightMultiple = lineHeightMultiple
        }
        if let minLineHeight = atoms[AtomicStyleKeys.minimumLineHeight] as? CGFloat {
            pStyleToModify!.minimumLineHeight = minLineHeight
        }
        if let maxLineHeight = atoms[AtomicStyleKeys.maximumLineHeight] as? CGFloat {
            pStyleToModify!.maximumLineHeight = maxLineHeight
        }
        if let lineSpacing = atoms[AtomicStyleKeys.lineSpacing] as? CGFloat {
            pStyleToModify!.lineSpacing = lineSpacing
        }
        
        // 缩进处理：如果原子属性中定义了，则覆盖
        // 优先使用 firstLineHeadIndent (如果定义了)
        // 否则，headIndent
        var headIndentApplied = false
        if let hi = atoms[AtomicStyleKeys.headIndent] as? CGFloat {
            pStyleToModify!.headIndent = hi
            headIndentApplied = true
        }
        if let flhi = atoms[AtomicStyleKeys.firstLineHeadIndent] as? CGFloat {
            pStyleToModify!.firstLineHeadIndent = flhi
        } else if headIndentApplied { // 如果设置了headIndent但没设置firstLineHeadIndent
             // 则首行与后续行缩进一致 (NSParagraphStyle中firstLineHeadIndent是相对headIndent的偏移，
             // 但我们这里存储的是绝对值，所以如果只有headIndent，firstLineHeadIndent应该等于它)
             // 不，更正：如果 parseAtomicParagraphProperties 正确计算了 firstLineHeadIndent (如它所做)
             // 那么这里就不需要这个 else if 了。如果 atoms 中有 firstLineHeadIndent 就用，没有就用继承的。
        }
        // ... 应用其他原子段落属性 ...

        if let finalPStyle = pStyleToModify {
            finalAttrs[.paragraphStyle] = finalPStyle.copy()
        }
        
        // << 新增：传递段落底纹颜色指令 >>
           // 优先级：直接十六进制 > 主题颜色指令
           if let hexAtom = atoms[AtomicStyleKeys.paraBackgroundColorHex] as? String {
               finalAttrs[ExtendedDocxStyleAttributes.paragraphBackgroundColorHex] = hexAtom
               // 清除可能从 base 继承的主题底纹指令
               finalAttrs.removeValue(forKey: ExtendedDocxStyleAttributes.paragraphBackgroundThemeColorName)
               finalAttrs.removeValue(forKey: ExtendedDocxStyleAttributes.paragraphBackgroundThemeColorTint)
               finalAttrs.removeValue(forKey: ExtendedDocxStyleAttributes.paragraphBackgroundThemeColorShade)
           } else if let themeNameAtom = atoms[AtomicStyleKeys.paraBackgroundThemeColorName] as? String {
               finalAttrs[ExtendedDocxStyleAttributes.paragraphBackgroundThemeColorName] = themeNameAtom
               if let tintAtom = atoms[AtomicStyleKeys.paraBackgroundThemeColorTint] as? String {
                   finalAttrs[ExtendedDocxStyleAttributes.paragraphBackgroundThemeColorTint] = tintAtom
               } else {
                   finalAttrs.removeValue(forKey: ExtendedDocxStyleAttributes.paragraphBackgroundThemeColorTint)
               }
               if let shadeAtom = atoms[AtomicStyleKeys.paraBackgroundThemeColorShade] as? String {
                   finalAttrs[ExtendedDocxStyleAttributes.paragraphBackgroundThemeColorShade] = shadeAtom
               } else {
                   finalAttrs.removeValue(forKey: ExtendedDocxStyleAttributes.paragraphBackgroundThemeColorShade)
               }
               // 清除可能从 base 继承的直接十六进制底纹指令
                if base[AtomicStyleKeys.paraBackgroundThemeColorName] == nil { // 仅当 base 中没有主题底纹时才清除
                   finalAttrs.removeValue(forKey: ExtendedDocxStyleAttributes.paragraphBackgroundColorHex)
                }
           }
           // 如果 atoms 中既没有 hex 也没有 theme，则 finalAttrs 会保留 base 中的底纹颜色信息
           // << 段落底纹指令传递结束 >>
        
        return finalAttrs
    }
    
    private func mapHighlightColor(_ value: String) -> UIColor? {
        switch value.lowercased() {
        case "yellow": return UIColor.yellow.withAlphaComponent(0.4)
        case "green": return UIColor.green.withAlphaComponent(0.3)
        case "red": return UIColor.red.withAlphaComponent(0.3)
        case "blue": return UIColor.blue.withAlphaComponent(0.3)
        case "cyan": return UIColor.cyan.withAlphaComponent(0.3)
        case "magenta": return UIColor.magenta.withAlphaComponent(0.3)
        case "lightgray", "lightGray": return UIColor.lightGray.withAlphaComponent(0.4)
        case "darkgray", "darkGray": return UIColor.darkGray.withAlphaComponent(0.4)
        default: return nil
        }
    }
}

// ExtendedDocxStyleAttributes 保持不变
struct ExtendedDocxStyleAttributes {
    // (与上一版相同)
    static let fontName = NSAttributedString.Key("com.docparser.style.fontName")
    static let fontSize = NSAttributedString.Key("com.docparser.style.fontSize")
    static let isBold = NSAttributedString.Key("com.docparser.style.isBold")
    static let isItalic = NSAttributedString.Key("com.docparser.style.isItalic")
    static let foregroundColorHex = NSAttributedString.Key("com.docparser.style.foregroundColorHex")
    static let highlightColorName = NSAttributedString.Key("com.docparser.style.highlightColorName")
    static let verticalAlignment = NSAttributedString.Key("com.docparser.style.verticalAlignment") // 存储 "superscript", "subscript", "baseline"
    static let underline = NSAttributedString.Key("com.docparser.style.underline") // 存储 "single", "double", "none" 等
    static let strikethrough = NSAttributedString.Key("com.docparser.style.strikethrough") // 存储 Bool
    
    // << 新增的主题颜色相关键 >>
    static let themeColorName = NSAttributedString.Key("com.docparser.style.theme.colorName")     // String (例如 "accent1")
    static let themeColorTint = NSAttributedString.Key("com.docparser.style.theme.colorTint")     // String (例如 "BF" 或 "75000")
    static let themeColorShade = NSAttributedString.Key("com.docparser.style.theme.colorShade")   // String (例如 "BF" 或 "75000")

    // 如果样式中也定义了主题背景/底纹颜色，也可以添加类似的键
    // static let themeFillName = NSAttributedString.Key("com.docparser.style.theme.fillName")
    // static let themeFillTint = NSAttributedString.Key("com.docparser.style.theme.fillTint")
    // static let themeFillShade = NSAttributedString.Key("com.docparser.style.theme.fillShade")
    
    // << 新增/确认段落底纹传递键 >>
       static let paragraphBackgroundColorHex = NSAttributedString.Key("com.docparser.style.para.bgColorHex")
       static let paragraphBackgroundThemeColorName = NSAttributedString.Key("com.docparser.style.para.bgThemeColorName")
       static let paragraphBackgroundThemeColorTint = NSAttributedString.Key("com.docparser.style.para.bgThemeColorTint")
       static let paragraphBackgroundThemeColorShade = NSAttributedString.Key("com.docparser.style.para.bgThemeColorShade")
}
