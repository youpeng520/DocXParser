// NumberingDefinition.swift
import Foundation
import UIKit // 用于潜在的颜色、字体定义
import SWXMLHash

// MARK: - Numbering Parser Errors (编号解析错误枚举)
enum NumberingParseError: Error {
    case fileNotFound               // numbering.xml 文件未找到
    case xmlParsingFailed(Error)    // XML 解析失败
}

// MARK: - Data Structures for Numbering Definitions (编号定义数据结构)

/**
 * 表示 <w:lvl> 元素中定义的特定级别列表项的格式。
 */
struct NumberingLevelDefinition {
    let levelIndex: Int                         // 级别索引, 例如 <w:ilvl w:val="0">
    var startValue: Int                         // 起始编号, 例如 <w:start w:val="1">
    var numberFormat: String                    // 编号格式, 例如 <w:numFmt w:val="decimal|bullet|...">
    var levelTextFormat: String                 // 级别文本格式模板, 例如 <w:lvlText w:val="%1.">
    var levelSuffix: String = "tab"             // 列表项编号后的后缀, 例如 <w:suff w:val="tab|space|nothing"> (默认为制表符)
    var wasStandardizedFromSymbolFont: Bool = false
    var requiresSymbolFont: Bool = false
    var originalSymbolFontName: String? = nil 

    // 从 <w:lvl><w:pPr> 解析的段落原子属性 (用于修改列表项段落样式)
    var paragraphPropertiesAtoms: [NSAttributedString.Key: Any] = [:]

    // 从 <w:lvl><w:rPr> 解析的列表项符号/编号的字符原子属性 (用于设置列表符号的样式)
    var runPropertiesAtoms: [NSAttributedString.Key: Any] = [:]
    
    // 构造函数
    init(levelIndex: Int, startValue: Int = 1, numberFormat: String = "bullet", levelTextFormat: String = "•") {
        self.levelIndex = levelIndex
        self.startValue = startValue
        self.numberFormat = numberFormat
        self.levelTextFormat = levelTextFormat
        // 注意：currentCounter 不再存储在这里，而是由 DocParser 为每个列表实例管理
    }
}

/**
 * 表示一个 <w:abstractNum> 定义，它是一个列表模板。
 * <w:num> 元素通常会链接到一个 <w:abstractNum> 并可能覆盖某些级别。
 */
struct AbstractNumberingDefinition {
    let abstractNumId: String                           // 抽象编号定义的ID
    var levels: [Int: NumberingLevelDefinition] = [:]   // 存储此模板下所有级别的定义 [levelIndex: Definition]
    var numStyleLink: String?                           // 链接的编号样式ID, 例如 <w:numStyleLink w:val="style_id">
    var styleLink: String?                              // 链接的段落样式ID, 例如 <w:styleLink w:val="style_id">
    
    var wasStandardizedFromSymbolFont: Bool = false // 保留这个，用于已成功标准化的
       var requiresSymbolFont: Bool = false          // 新增：如果为true，则必须使用rPr中定义的字体
       var originalSymbolFontName: String? = nil     // 新增：存储原始符号字体名，如果 requiresSymbolFont 为 true
    /**
     * 获取或创建一个指定级别的 NumberingLevelDefinition。
     * 如果指定级别不存在，则创建一个默认的项目符号级别。
     * - Parameter index: 级别索引。
     * - Returns: 对应级别的 NumberingLevelDefinition。
     */
    mutating func level(at index: Int) -> NumberingLevelDefinition {
        if let existingLevel = levels[index] {
            return existingLevel
        } else {
            // 如果特定级别未定义，创建一个默认的项目符号级别
            let newLevel = NumberingLevelDefinition(levelIndex: index)
            levels[index] = newLevel
            return newLevel
        }
    }

    // 值类型的默认成员拷贝是足够的，因为其成员也是值类型或其集合
    // 如果需要显式拷贝（例如为了清晰或将来添加引用类型成员），可以取消注释
    // func copy() -> AbstractNumberingDefinition {
    //     return self
    // }
}

/**
 * 顶层类，负责解析 `numbering.xml` 并管理所有的编号定义。
 */
class NumberingDefinitionParser {
    typealias XMLNode = XMLIndexer
    
    // 存储抽象编号定义: abstractNumId -> AbstractNumberingDefinition
    private var abstractNumDefinitions: [String: AbstractNumberingDefinition] = [:]
    
    // 存储具体编号实例定义: numId -> AbstractNumberingDefinition
    // <w:num> 元素通过链接到 <w:abstractNum> 并应用 <w:lvlOverride> 来形成最终的列表定义。
    private var concreteNumDefinitions: [String: AbstractNumberingDefinition] = [:]

    init() {}

    /**
     * 解析 `word/numbering.xml` 文件。
     * - Parameter numberingFileURL: numbering.xml 文件的 URL。
     * - Parameter styleParser: 传入 StyleParser 实例，用于解析 <w:lvl> 中 <w:pPr> 和 <w:rPr> 的原子属性。
     * - Throws: NumberingParseError 如果文件未找到或解析失败。
     */
    func parseNumberingDefinitions(numberingFileURL: URL, styleParser: StyleParser) throws {
        guard FileManager.default.fileExists(atPath: numberingFileURL.path) else {
            print("NumberingDefinitionParser: numbering.xml 未找到 at \(numberingFileURL.path)")
            throw NumberingParseError.fileNotFound
        }

        do {
            let xmlString = try String(contentsOf: numberingFileURL, encoding: .utf8)
            let xml = XMLHash.parse(xmlString)

            // 1. 解析 <w:abstractNum> 元素 (列表模板)
            for abstractNumNode in xml["w:numbering"]["w:abstractNum"].all {
                guard let abstractNumId = abstractNumNode.attributeValue(by: "w:abstractNumId") else { continue }
                
                var definition = AbstractNumberingDefinition(abstractNumId: abstractNumId)
                definition.numStyleLink = abstractNumNode["w:numStyleLink"].attributeValue(by: "w:val")
                definition.styleLink = abstractNumNode["w:styleLink"].attributeValue(by: "w:val")

                for lvlNode in abstractNumNode["w:lvl"].all {
                    guard let ilvlStr = lvlNode.attributeValue(by: "w:ilvl"), let ilvl = Int(ilvlStr) else { continue }
                    
                    let startVal = lvlNode["w:start"].attributeValue(by: "w:val").flatMap { Int($0) } ?? 1
                    let numFmt = lvlNode["w:numFmt"].attributeValue(by: "w:val") ?? "bullet"
                    
                    var lvlText = lvlNode["w:lvlText"].attributeValue(by: "w:val") ?? "•"
                    
                    var levelDef = NumberingLevelDefinition(levelIndex: ilvl, startValue: startVal, numberFormat: numFmt, levelTextFormat: lvlText)
                    levelDef.levelSuffix = lvlNode["w:suff"].attributeValue(by: "w:val") ?? "tab"
                    
                  
                    let rFontsNode = lvlNode["w:rPr"]["w:rFonts"]
                    let symbolFontName = rFontsNode.attributeValue(by: "w:ascii") ?? rFontsNode.attributeValue(by: "w:hAnsi") ?? ""
                    if (symbolFontName.lowercased() == "symbol" || symbolFontName.lowercased() == "wingdings") && lvlText == "\u{F0B7}" { // U+F0B7
                        lvlText = "\u{2022}"   // 标准化为 • (U+2022)
                        // 标记一下，这个符号已经被标准化了，之后 DocParser 可以决定是否移除 Symbol 字体
                        levelDef.wasStandardizedFromSymbolFont = true // 需要在 NumberingLevelDefinition 中添加这个 Bool 属性
                    }
                    levelDef.levelTextFormat = lvlText
                    
                    // 解析 <w:lvl><w:pPr> (列表项段落属性)
                    if lvlNode["w:pPr"].element != nil {
                        // 调用 StyleParser (现在是 internal/public) 方法解析原子段落和运行属性
                        let (paraAtoms, _) = styleParser.parseAtomicParagraphProperties(from: lvlNode["w:pPr"])
                        levelDef.paragraphPropertiesAtoms = paraAtoms
                    }
                    
                    // 解析 <w:lvl><w:rPr> (列表符号字符属性)
                    if lvlNode["w:rPr"].element != nil {
                        // 调用 StyleParser (现在是 internal/public) 方法解析原子运行属性
                        levelDef.runPropertiesAtoms = styleParser.parseAtomicRunProperties(from: lvlNode["w:rPr"])
                    }
                    definition.levels[ilvl] = levelDef
                }
                abstractNumDefinitions[abstractNumId] = definition
            }

            // 2. 解析 <w:num> 元素 (具体列表实例)，链接到 <w:abstractNum> 并应用覆盖
            for numNode in xml["w:numbering"]["w:num"].all {
                guard let numId = numNode.attributeValue(by: "w:numId") else { continue }
                
                guard let linkedAbstractNumId = numNode["w:abstractNumId"].attributeValue(by: "w:val"),
                      var baseDefinitionCopy = abstractNumDefinitions[linkedAbstractNumId] // 获取副本进行修改 (struct 默认是值拷贝)
                else {
                    // print("NumberingDefinitionParser: <w:num> numId='\(numId)' 链接到一个不存在的 abstractNumId='\(numNode["w:abstractNumId"].attributeValue(by: "w:val") ?? "nil")'")
                    var fallbackDef = AbstractNumberingDefinition(abstractNumId: "fallback_for_\(numId)")
                    fallbackDef.levels[0] = NumberingLevelDefinition(levelIndex: 0) // 提供一个非常基础的默认级别
                    concreteNumDefinitions[numId] = fallbackDef
                    continue
                }

                // 处理 <w:lvlOverride w:ilvl="..."> (级别覆盖)
                for lvlOverrideNode in numNode["w:lvlOverride"].all {
                    guard let ilvlStr = lvlOverrideNode.attributeValue(by: "w:ilvl"), let ilvl = Int(ilvlStr) else { continue }
                    
                    // 获取当前级别定义，如果 baseDefinitionCopy 中没有，则从模板创建一个
                    var levelToModify = baseDefinitionCopy.levels[ilvl] ?? NumberingLevelDefinition(levelIndex: ilvl)
                    var wasCompletelyReplaced = false

                    // 检查 <w:lvlOverride> 内部是否有 <w:lvl> 元素，它会完全替换该级别的定义
                    if lvlOverrideNode["w:lvl"].element != nil {
                        let newLvlIndexer = lvlOverrideNode["w:lvl"]
                        
                        let startVal = newLvlIndexer["w:start"].attributeValue(by: "w:val").flatMap { Int($0) } ?? levelToModify.startValue
                        let numFmt = newLvlIndexer["w:numFmt"].attributeValue(by: "w:val") ?? levelToModify.numberFormat
                        let lvlText = newLvlIndexer["w:lvlText"].attributeValue(by: "w:val") ?? levelToModify.levelTextFormat
                        
                        
                        
                        var newOverridingLevelDef = NumberingLevelDefinition(levelIndex: ilvl, startValue: startVal, numberFormat: numFmt, levelTextFormat: lvlText)
                        newOverridingLevelDef.levelSuffix = newLvlIndexer["w:suff"].attributeValue(by: "w:val") ?? levelToModify.levelSuffix
                        
                        if newLvlIndexer["w:pPr"].element != nil {
                             let (paraAtoms, _) = styleParser.parseAtomicParagraphProperties(from: newLvlIndexer["w:pPr"])
                             newOverridingLevelDef.paragraphPropertiesAtoms = paraAtoms
                        }
                        if newLvlIndexer["w:rPr"].element != nil {
                            newOverridingLevelDef.runPropertiesAtoms = styleParser.parseAtomicRunProperties(from: newLvlIndexer["w:rPr"])
                        }
                        
                        // <w:startOverride> 优先于内部 <w:lvl> 的 <w:start>
                        if lvlOverrideNode["w:startOverride"].element != nil {
                           if let startOverrideVal = lvlOverrideNode["w:startOverride"].attributeValue(by: "w:val").flatMap({ Int($0) }) {
                               newOverridingLevelDef.startValue = startOverrideVal
                           }
                        }
                        baseDefinitionCopy.levels[ilvl] = newOverridingLevelDef // 完全替换级别定义
                        wasCompletelyReplaced = true
                    }
                    
                    // 如果没有被内部 <w:lvl> 完全替换，则仅应用 <w:startOverride> (如果存在)
                    if !wasCompletelyReplaced {
                        if lvlOverrideNode["w:startOverride"].element != nil {
                            if let startOverrideVal = lvlOverrideNode["w:startOverride"].attributeValue(by: "w:val").flatMap({ Int($0) }) {
                                levelToModify.startValue = startOverrideVal
                                baseDefinitionCopy.levels[ilvl] = levelToModify // 更新修改后的级别
                            }
                        } else if baseDefinitionCopy.levels[ilvl] == nil { // 如果此级别之前不存在于副本中
                            baseDefinitionCopy.levels[ilvl] = levelToModify // 添加它
                        }
                    }
                } // 结束 for lvlOverrideNode
                concreteNumDefinitions[numId] = baseDefinitionCopy
            } // 结束 for numNode
            // print("NumberingDefinitionParser: 解析完成. Abstract: \(abstractNumDefinitions.count), Concrete: \(concreteNumDefinitions.count)")

        } catch {
            throw NumberingParseError.xmlParsingFailed(error)
        }
    }

    // MARK: - Public Accessors and Formatting (公共访问器和格式化方法)

    /**
     * 公共访问器：获取解析后的具体编号定义字典。
     * DocParser 会使用这个来获取列表的元数据。
     */
    public func getConcreteNumberingDefinitions() -> [String: AbstractNumberingDefinition] {
        return self.concreteNumDefinitions
    }

    /**
     * 根据级别定义和当前计数格式化列表项的文本 (例如 "%1." 替换为 "1.")。
     * 这个方法由 DocParser 调用。
     * - Parameter formatString: 级别文本格式模板 (来自 <w:lvlText w:val="...">)。
     * - Parameter currentValue: 当前级别的计算出的编号值。 (DocParser 维护)
     * - Parameter numberFormat: 当前级别的数字格式 (来自 <w:numFmt>)。
     * - Parameter numId: 当前列表实例的 ID (用于多级编号中查找其他级别的计数器)。
     * - Parameter allLevelsCounters: 包含此 numId 所有级别当前计数器的字典 [levelIndex: count]。 (DocParser 维护)
     * - Parameter allLevelDefinitions: 包含此 numId 所有级别定义的字典 [levelIndex: NumberingLevelDefinition]。
     * - Returns: 格式化后的列表项编号字符串。
     */
    public func formatLevelText(
        _ formatString: String,
        currentValue: Int, // 注意：这个参数现在可能不是必需的，因为 allLevelsCounters 应该包含了当前级别的正确计数
        numberFormat: String,
        numId: String,
        allLevelsCounters: [Int: Int],
        allLevelDefinitions: [Int: NumberingLevelDefinition]
    ) -> String {
        var result = formatString
        
        // 替换 formatString 中的 %N 占位符
        // %1 对应级别 0, %2 对应级别 1, 等等。
        for i in 1...9 { // Word 支持最多9级占位符
            let placeholder = "%\(i)"
            if result.contains(placeholder) {
                let targetLevelIndex = i - 1
                
                // 从 DocParser 传入的计数器中获取该级别的值
                let valueForLevel = allLevelsCounters[targetLevelIndex] ??
                                    (allLevelDefinitions[targetLevelIndex]?.startValue ?? 1) // 回退到起始值
                
                // 获取该级别的数字格式
                let numFmtForLevel = allLevelDefinitions[targetLevelIndex]?.numberFormat ?? "decimal" // 默认为十进制
                
                let formattedNumberOfLevel = formatNumber(valueForLevel, format: numFmtForLevel)
                result = result.replacingOccurrences(of: placeholder, with: formattedNumberOfLevel)
            }
        }
        return result
    }

    /**
     * 将数字根据指定的格式（如罗马数字、字母等）转换为字符串。
     * - Parameter number: 要格式化的数字。
     * - Parameter format: 格式字符串 (来自 <w:numFmt w:val="...">)。
     * - Returns: 格式化后的字符串。
     */
    private func formatNumber(_ number: Int, format: String) -> String {
        switch format.lowercased() {
        case "decimal": return "\(number)"
        case "upperroman": return numberToRoman(number, uppercase: true)
        case "lowerroman": return numberToRoman(number, uppercase: false)
        case "upperletter": return numberToLetters(number, uppercase: true)
        case "lowerletter": return numberToLetters(number, uppercase: false)
        case "ordinal": return "\(number)" + ordinalSuffix(number)
        case "cardinaltext": return numberToWords(number) // 复杂，暂返回数字
        case "ordinaltext": return numberToWords(number, ordinal: true) // 复杂，暂返回数字
        case "bullet": return "•" // 默认项目符号, 通常由 levelTextFormat 直接提供
        case "decimalzero": return String(format: "%02d", number) // 例如 01, 02...
        // TODO: 添加更多 Word 支持的格式，例如:
        // "chineseCounting", "hebrew1", "thaiLetters", "ganada", "chosung" 等等
        case "none": return ""
        default:
            // print("NumberingDefinitionParser: 未知编号格式 '\(format)', 返回十进制数字。")
            return "\(number)"
        }
    }
    
    // MARK: - Helper Number Formatting Functions (辅助数字格式化函数)
    
    private func numberToRoman(_ number: Int, uppercase: Bool) -> String {
        guard number > 0 && number < 4000 else { return "\(number)" }
        let romanValues = [
            (1000, "M"), (900, "CM"), (500, "D"), (400, "CD"),
            (100, "C"), (90, "XC"), (50, "L"), (40, "XL"),
            (10, "X"), (9, "IX"), (5, "V"), (4, "IV"), (1, "I")
        ]
        var result = ""
        var num = number
        for (value, numeral) in romanValues {
            while num >= value {
                result += numeral
                num -= value
            }
        }
        return uppercase ? result : result.lowercased()
    }

    private func numberToLetters(_ number: Int, uppercase: Bool) -> String {
        guard number > 0 else { return "" } // A=1, B=2 ... Z=26, AA=27
        var num = number
        var letters = ""
        let baseScalarValue = uppercase ? UnicodeScalar("A").value : UnicodeScalar("a").value
        
        while num > 0 {
            num -= 1 // 调整为0-indexed (A=0, B=1, ..., Z=25)
            let remainder = num % 26
            letters = String(UnicodeScalar(baseScalarValue + UInt32(remainder))!) + letters
            num /= 26
        }
        return letters.isEmpty ? (uppercase ? "A" : "a") : letters // 处理 number=1 的情况，确保不为空
    }

    private func ordinalSuffix(_ number: Int) -> String {
        let lastDigit = number % 10
        let lastTwoDigits = number % 100
        if lastTwoDigits >= 11 && lastTwoDigits <= 13 { return "th" }
        switch lastDigit {
        case 1: return "st"
        case 2: return "nd"
        case 3: return "rd"
        default: return "th"
        }
    }
    
    private func numberToWords(_ number: Int, ordinal: Bool = false) -> String {
        // 这是一个复杂的函数，通常需要一个库或大量代码。
        // 暂时返回数字字符串作为占位符。
        if ordinal { return "\(number)" + ordinalSuffix(number) }
        return "\(number)"
    }
}
