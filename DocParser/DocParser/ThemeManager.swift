//
//  ThemeManager.swift
//  DocParser
//
//  Created by ZJS on 2025/5/12.
//  Copyright © 2025 paf. All rights reserved.
//

import Foundation
import UIKit
import SWXMLHash

// MARK: - ThemeManager Error
enum ThemeManagerError: Error {
    case themeFileNotFound
    case xmlParsingFailed(Error)
    case colorDefinitionError(String)
}

// MARK: - ThemeManager Class
class ThemeManager {
    typealias XMLNode = XMLIndexer

    private var themeColors: [String: String] = [:] // 存储主题颜色名称到其RGB十六进制值的映射

    // OOXML主题颜色名称常量 (theme1.xml中 <a:clrScheme> 下的元素名)
    struct ThemeColorKeys {
        static let dark1 = "dk1"
        static let light1 = "lt1"
        static let dark2 = "dk2"
        static let light2 = "lt2"
        static let accent1 = "accent1"
        static let accent2 = "accent2"
        static let accent3 = "accent3"
        static let accent4 = "accent4"
        static let accent5 = "accent5"
        static let accent6 = "accent6"
        static let hyperlink = "hlink"
        static let followedHyperlink = "folHlink"
        // 背景和文本颜色通常映射到 dk1/lt1 或 dk2/lt2
        static let background1 = "bg1" // 通常是 lt1
        static let text1 = "tx1"       // 通常是 dk1
        static let background2 = "bg2" // 通常是 lt2
        static let text2 = "tx2"       // 通常是 dk2
    }

    init() {}

    /**
     * 解析主题文件 (通常是 word/theme/theme1.xml)
     * - Parameter themeFileURL: 主题文件的URL
     * - Throws: ThemeManagerError
     */
    func parseTheme(themeFileURL: URL) throws {
        guard FileManager.default.fileExists(atPath: themeFileURL.path) else {
            print("ThemeManager: 主题文件未找到 at \(themeFileURL.path)")
            throw ThemeManagerError.themeFileNotFound
        }

        do {
            let xmlString = try String(contentsOf: themeFileURL, encoding: .utf8)
            let xml = XMLHash.parse(xmlString)

            // <a:themeElements><a:clrScheme>
            let clrSchemeNode = xml["a:theme"]["a:themeElements"]["a:clrScheme"]

            // 遍历所有颜色定义 (dk1, lt1, accent1, 等)
            for colorElement in clrSchemeNode.children {
                let themeColorName = colorElement.element?.name // 例如 "a:dk1", 我们需要 "dk1"
                guard let name = themeColorName?.replacingOccurrences(of: "a:", with: "") else { continue }

                // 尝试获取 <a:srgbClr w:val="RRGGBB"/>
                if let srgbClrNode = colorElement["a:srgbClr"].element,
                   let hexVal = srgbClrNode.attribute(by: "val")?.text {
                    themeColors[name] = hexVal
                }
                // 也可以处理 <a:sysClr w:val="windowText"/> 等，并映射到已知颜色
                // 例如，如果文档使用系统颜色，可以将它们映射到themeColors的特定条目
                else if let sysClrNode = colorElement["a:sysClr"].element,
                          let sysClrVal = sysClrNode.attribute(by: "val")?.text {
                    // 简单的映射，可以根据需要扩展
                    switch sysClrVal.lowercased() {
                        case "windowtext": themeColors[name] = themeColors[ThemeColorKeys.dark1] ?? "000000" // 默认为黑色
                        case "window": themeColors[name] = themeColors[ThemeColorKeys.light1] ?? "FFFFFF" // 默认为白色
                        // 可以添加更多系统颜色映射
                        default: break
                    }
                }
            }
            // print("ThemeManager: 已解析的主题颜色: \(themeColors)")

        } catch {
            throw ThemeManagerError.xmlParsingFailed(error)
        }
    }

    /**
     * 根据主题颜色名称、可选的tint和shade获取UIColor。
     * - Parameter name: 主题颜色名称 (例如 "accent1", "dk1").
     * - Parameter tint: 可选的tint值 (十六进制字符串, 例如 "BF" 代表 75% 的亮度).
     * - Parameter shade: 可选的shade值 (十六进制字符串, 例如 "BF" 代表 75% 的暗度).
     * - Returns: 计算后的UIColor，如果基础颜色未找到则为nil.
     */
    func getColor(forName name: String, tint: String? = nil, shade: String? = nil) -> UIColor? {
        guard let baseHexColor = themeColors[name] else {
            // print("ThemeManager: 未找到基础主题颜色 '\(name)'")
            // 如果是 tx1/dk1 等常用颜色缺失，可以考虑一个更硬性的后备
            if name == ThemeColorKeys.text1 || name == ThemeColorKeys.dark1 { return UIColor(hex: "000000") } // 默认黑色
            if name == ThemeColorKeys.background1 || name == ThemeColorKeys.light1 { return UIColor(hex: "FFFFFF") } // 默认白色
            return nil
        }

        var finalHexColor = baseHexColor

        if let tintValueHex = tint, let tintFactor = self.percentageFromHex(tintValueHex) {
            // Tint: R = R_base * (1-factor) + 255 * factor
            finalHexColor = applyTintToHex(hexColor: finalHexColor, factor: CGFloat(tintFactor))
        } else if let shadeValueHex = shade, let shadeFactor = self.percentageFromHex(shadeValueHex) {
            // Shade: R = R_base * factor
            // 注意：OOXML的 "shade" 通常意味着“变暗”，所以 factor 越小颜色越暗。
            // 但 w:val="BF" (75%) 的 shade 意味着保留75%的原始颜色。
            // 因此，这里的 factor 应该是 (1.0 - XML中定义的shade百分比) 如果shade值代表变暗的程度
            // 或者直接是 XML中定义的shade百分比如果它代表保留原始颜色的程度。
            // 根据 ECMA-376 Part 1 - 17.7.2.2 themeShade, val attribute is "Specifies the shade value applied to the color"
            // 通常，shade值如 "BF" (75%) 意味着结果是原始颜色的75%。
            finalHexColor = applyShadeToHex(hexColor: finalHexColor, factor: CGFloat(shadeFactor))
        }
        return UIColor(hex: finalHexColor)
    }

    // 将 OOXML 的 tint/shade 百分比值 (例如 "BF000" -> 75%, "80000" -> 50%) 转换为 0.0-1.0 的因子
    private func percentageFromHex(_ hexValue: String) -> Double? {
        // OOXML 的 tint/shade 值是 0-100000 的整数，其中 100000 代表 100%
        // 有时它们以十六进制形式出现，但通常在解析属性时已经是字符串形式的十进制数
        // 例如 <w:themeTint w:val="75000"/>
        // 但如果直接从XML中读到的 w:val 是像 "BF" 这样的，它代表的是最终颜色的百分比，而不是操作的强度。
        // 例如 "BF" (hex for 191) -> 191/255.0 (约 0.749)
        // 我们假设这里传入的 tint/shade 是形如 "BF" (191) 的十六进制字符串，代表新组分的比例（对于shade）或与白色的混合比例（对于tint的简化）。
        // 或者更常见的是一个0-255的范围，如 "BF" -> 191。
        // 实际上，tint/shade的w:val通常是一个0-100000的整数值，
        // 但在w:color的themeTint/themeShade属性里可能是"BF"这样的字节值。
        // 我们这里处理的是后者，即来自 <w:color w:themeTint="BF"/> 这样的属性。
        // 这个 "BF" (191) 代表了对原始颜色的修改程度。
        // 对于 Tint: factor = (255 - val) / 255.0 (val 是 "BF" 转成的十进制 191) => factor 越小，越接近白色
        // 对于 Shade: factor = val / 255.0 (val 是 "BF" 转成的十进制 191) => factor 越小，越接近黑色
        //
        // 让我们简化：如果XML是 <... w:themeTint="99999">, 这里的 val 是 99999 (99.999% tint)
        // 如果XML是 <... w:themeTint="BF"> (在<w:color>的属性中), "BF" 是十六进制的字节值。
        // 假设我们这里的 tint/shade 参数是这个字节值的字符串形式。
        
        // 将 "BF" 这种两位十六进制字符串转为 0-1.0 的因子
        // 这个因子代表了修改的强度或结果的比例，具体取决于tint或shade的公式
        if hexValue.count == 2 { // 例如 "BF"
            if let intVal = UInt8(hexValue, radix: 16) {
                return Double(intVal) / 255.0 // 代表一个0-1范围的强度或比例
            }
        } else if let intVal = Int(hexValue), intVal >= 0 && intVal <= 100000 {
            // 如果是 "75000" 这样的值 (0-100000)
            return Double(intVal) / 100000.0
        }
        // print("ThemeManager: 无法从'\(hexValue)'解析百分比")
        return nil // 解析失败
    }

    private func applyTintToHex(hexColor: String, factor: CGFloat) -> String {
        // Tint 公式: C_new = C_orig * (1-factor) + 255 * factor
        // 但是，OOXML的tint通常是将颜色与白色混合。
        // factor 来自 percentageFromHex，如果输入是 "BF" (191), factor 约为 0.749.
        // 如果 tint="E6" (230), factor=230/255=0.9.
        // 实际 tint 操作: C_new = C_orig + (255 - C_orig) * factor (factor是0-1的tint强度)
        // 如果 percentageFromHex 返回的是 tint 的强度 (例如 0.25 表示 25% tint toward white)
        guard var color = UIColor(hex: hexColor) else { return hexColor }
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: nil)

        r = r + (1.0 - r) * factor
        g = g + (1.0 - g) * factor
        b = b + (1.0 - b) * factor

        r = min(1.0, max(0.0, r))
        g = min(1.0, max(0.0, g))
        b = min(1.0, max(0.0, b))

        return String(format: "%02X%02X%02X", Int(r*255), Int(g*255), Int(b*255))
    }

    private func applyShadeToHex(hexColor: String, factor: CGFloat) -> String {
        // Shade 公式: C_new = C_orig * factor
        // factor 来自 percentageFromHex。如果 shade="BF" (191), factor 约为 0.749.
        // 这意味着结果颜色是原始颜色的 74.9%。
        guard var color = UIColor(hex: hexColor) else { return hexColor }
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: nil)

        r *= factor
        g *= factor
        b *= factor

        r = min(1.0, max(0.0, r))
        g = min(1.0, max(0.0, g))
        b = min(1.0, max(0.0, b))
        
        return String(format: "%02X%02X%02X", Int(r*255), Int(g*255), Int(b*255))
    }

    // 默认文本颜色 (通常是深色主题色)
    func getDefaultTextColor() -> UIColor {
        return getColor(forName: ThemeColorKeys.text1) ?? getColor(forName: ThemeColorKeys.dark1) ?? UIColor.black
    }
}
