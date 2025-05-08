////
////  DocParser.swift
////  DocParser
////
////  Created by Wesley Yang on 16/4/20.
////  Copyright © 2016年 paf. All rights reserved.
////
//
//import Foundation
//import Zip
//import SWXMLHash
//
//enum DocXMLAtt:String {
//    
//    case Value = "w:val"
//}
//
//class DocParser{
//    typealias XMLNode = XMLIndexer
//    
//    func parseFile(fileURL:URL) throws -> NSAttributedString{
//        //unzip
//        let unzipDirectory = try Zip.quickUnzipFile(fileURL)
//        print(unzipDirectory)
//        
//        let mainDocument = unzipDirectory.appendingPathComponent("word/document.xml")
//        print(mainDocument.path)
//        
//        let xml = try XMLHash.parse(String(contentsOf:mainDocument));
//        return parseXML(xml: xml)
//    }
//    
//    private func parseXML(xml:XMLNode) -> NSAttributedString{
//        
//        let bodyXML = xml["w:document"]["w:body"]
//        
//        let paragraphs = bodyXML["w:p"].all
//        
//        let docAttString = NSMutableAttributedString()
//        
//        for paragraphXML in paragraphs {
//            print("found para")
//            let paraPropertyXML = paragraphXML["w:pPr"]
//            let paraStyle = getParagraphStyleFromXML(paraPropertyXML: paraPropertyXML)
//            print(paraStyle)
//            
//            let paragraphString = NSMutableAttributedString()
//            
//            for node in paragraphXML.children {
//                if node.element?.name == "w:r" {
//                    print("hello")
//                    if let attStr = getAttStringFromRun(run: node){
//                        paragraphString.append(attStr)
//                    }
//                }else if node.element?.name == "w:hyperlink"{
//                    if let attStr = getAttStringFromRun(run: node["w:r"]){
//                        paragraphString.append(attStr)
//                    }
//                }
//            }
//            
//            paragraphString .mutableString .append("\n")
//            
//            let fullRange = NSRange.init(location: 0, length: paragraphString.length)
//            paragraphString.addAttributes(paraStyle, range: fullRange)
//            
//            docAttString .append(paragraphString)
//        }
//        
//        return docAttString
//    }
//    
//    //<w:jc>
//    private func getParagraphStyleFromXML(paraPropertyXML: XMLIndexer) -> [NSAttributedString.Key: Any] {
//        let jcXML = paraPropertyXML["w:jc"]
//        let paraStyle = NSMutableParagraphStyle()
//
//        if let att = jcXML.element?.attribute(by: DocXMLAtt.Value.rawValue)?.text {
//            switch att {
//            case "left": paraStyle.alignment = .left
//            case "right": paraStyle.alignment = .right
//            case "center": paraStyle.alignment = .center
//            case "justified": paraStyle.alignment = .justified
//            default: break
//            }
//        }
//        
//        return [.paragraphStyle: paraStyle]
//    }
//    
//    private func getAttStringFromRun(run:XMLNode) -> NSAttributedString? {
//        //get text
//        if let text = run["w:t"].element?.text {
//        
//            //int
//            var isBold = false
//            var isItalic = false
//            var isUnderline = false
//            var fontSize : Float = 12.0
//            var currentFontName : String? = nil
//            let attString = NSMutableAttributedString.init(string: text)
//
//            let propertyNode = run["w:rPr"]
//            
//            func processFontFromFontNode(node:XMLNode){
//                var currentFontName = node.element?.attribute(by: "w:ascii")?.text
//                if currentFontName == nil {
//                    currentFontName = node.element?.attribute(by: "w:cs")?.text
//                }
//                if currentFontName == nil {
//                    currentFontName = "Arial"
//                }
//            }
//            
//            func processFontSizeFromNode(node:XMLNode){
//                if let size = node.element?.attribute(by: "w:val")?.text,
//                   let sizeFloat = Float(size) {
//                    _ = sizeFloat / 2
//                } else {
//                    print("Font Size not found or invalid")
//                }
//            }
//            if propertyNode["w:b"].element != nil {
//                isBold = true
//            }
//            if (propertyNode["w:i"].element) != nil {
//                isItalic = true
//            }
//            if (propertyNode["w:u"].element) != nil {
//                isUnderline = true
//            }
//            
//            var traits = UIFontDescriptor.SymbolicTraits()
//            if isBold {
//                traits = traits.union(.traitBold)
//            }
//            if isItalic {
//                traits = traits.union(.traitItalic)
//            }
//            //get size
//            processFontSizeFromNode(node: propertyNode["w:sz"])
//            
//            //get font name
//            processFontFromFontNode(node: propertyNode["w:rFonts"])
//            
//            
//            // 获取字体描述符并安全解包
//                let fontDescriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .body)
//                let font: UIFont
//                
//                if let descriptorWithTraits = fontDescriptor.withSymbolicTraits(traits) {
//                    font = UIFont(descriptor: descriptorWithTraits, size: CGFloat(fontSize))
//                } else {
//                    // 如果无法应用特性，尝试创建自定义字体
//                    if let fontName = currentFontName {
//                        font = UIFont(name: fontName, size: CGFloat(fontSize)) ?? UIFont.systemFont(ofSize: CGFloat(fontSize))
//                    } else {
//                        font = UIFont.systemFont(ofSize: CGFloat(fontSize))
//                    }
//                }
//        
//            let fullRange = NSRange.init(location: 0, length: attString.length)
//            attString.beginEditing()
//            attString.setAttributes([NSAttributedString.Key.font:font], range: fullRange)
//            if isUnderline {
//                attString.addAttribute(NSAttributedString.Key.underlineStyle, value: 1, range: fullRange)
//            }
//            attString.endEditing()
//            
//            return attString
//        }
//      
//        return nil
//    }
//
//    
//    
//}



//import Foundation
//import Zip
//import SWXMLHash
//import UIKit
//
//enum DocXMLAtt: String {
//    case Value = "w:val"
//}
//
//class DocParser {
//    typealias XMLNode = XMLIndexer
//
//    func parseFile(fileURL: URL) throws -> NSAttributedString {
//        // 解压文件
//        let unzipDirectory = try Zip.quickUnzipFile(fileURL)
//        print("解压目录: \(unzipDirectory)")
//
//        let mainDocument = unzipDirectory.appendingPathComponent("word/document.xml")
//        print("主文档路径: \(mainDocument.path)")
//
//        let xml = try XMLHash.parse(String(contentsOf: mainDocument))
//        return try parseXML(xml: xml, unzipDirectory: unzipDirectory)
//    }
//
//    private func parseXML(xml: XMLNode, unzipDirectory: URL) throws -> NSAttributedString {
//        let bodyXML = xml["w:document"]["w:body"]
//        let paragraphs = bodyXML["w:p"].all
//
//        let docAttString = NSMutableAttributedString()
//
//        for paragraphXML in paragraphs {
//            print("发现段落")
//            let paraPropertyXML = paragraphXML["w:pPr"]
//            let paraStyle = getParagraphStyleFromXML(paraPropertyXML: paraPropertyXML)
//
//            let paragraphString = NSMutableAttributedString()
//
//            for node in paragraphXML.children {
//                if node.element?.name == "w:r" {
//                    if let attStr = getAttStringFromRun(run: node) {
//                        paragraphString.append(attStr)
//                    }
//                } else if node.element?.name == "w:hyperlink" {
//                    if let attStr = getAttStringFromRun(run: node["w:r"]) {
//                        paragraphString.append(attStr)
//                    }
//                } else if node.element?.name == "w:drawing" {
//                    if let imageAttachment = try processImage(node: node, unzipDirectory: unzipDirectory) {
//                        let attributedImage = NSAttributedString(attachment: imageAttachment)
//                        paragraphString.append(attributedImage)
//                    }
//                } else if node.element?.name == "w:chart" {
//                    if let chartDescription = processChart(node: node) {
//                        let attributedChart = NSAttributedString(string: chartDescription)
//                        paragraphString.append(attributedChart)
//                    }
//                }
//            }
//
//            paragraphString.mutableString.append("\n")
//
//            let fullRange = NSRange(location: 0, length: paragraphString.length)
//            paragraphString.addAttributes(paraStyle, range: fullRange)
//
//            docAttString.append(paragraphString)
//        }
//
//        return docAttString
//    }
//
//    //<w:jc>
//    private func getParagraphStyleFromXML(paraPropertyXML: XMLIndexer) -> [NSAttributedString.Key: Any] {
//        let jcXML = paraPropertyXML["w:jc"]
//        let paraStyle = NSMutableParagraphStyle()
//
//        if let att = jcXML.element?.attribute(by: DocXMLAtt.Value.rawValue)?.text {
//            switch att {
//            case "left": paraStyle.alignment = .left
//            case "right": paraStyle.alignment = .right
//            case "center": paraStyle.alignment = .center
//            case "justified": paraStyle.alignment = .justified
//            default: break
//            }
//        }
//
//        return [.paragraphStyle: paraStyle]
//    }
//
//    private func getAttStringFromRun(run: XMLNode) -> NSAttributedString? {
//        // 获取文本
//        if let text = run["w:t"].element?.text {
//            // 初始化样式和属性
//            var isBold = false
//            var isItalic = false
//            var isUnderline = false
//            var fontSize: Float = 12.0
//            var currentFontName: String? = nil
//            let attString = NSMutableAttributedString(string: text)
//
//            let propertyNode = run["w:rPr"]
//
//            // 处理字体
//            func processFontFromFontNode(node: XMLNode) {
//                currentFontName = node.element?.attribute(by: "w:ascii")?.text ?? node.element?.attribute(by: "w:cs")?.text ?? "Arial"
//            }
//
//            // 处理字体大小
//            func processFontSizeFromNode(node: XMLNode) {
//                if let size = node.element?.attribute(by: "w:val")?.text, let sizeFloat = Float(size) {
//                    fontSize = sizeFloat / 2
//                }
//            }
//
//            if propertyNode["w:b"].element != nil { isBold = true }
//            if propertyNode["w:i"].element != nil { isItalic = true }
//            if propertyNode["w:u"].element != nil { isUnderline = true }
//
//            var traits = UIFontDescriptor.SymbolicTraits()
//            if isBold { traits.insert(.traitBold) }
//            if isItalic { traits.insert(.traitItalic) }
//
//            processFontSizeFromNode(node: propertyNode["w:sz"])
//            processFontFromFontNode(node: propertyNode["w:rFonts"])
//
//            let fontDescriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .body)
//            let font: UIFont
//
//            if let descriptorWithTraits = fontDescriptor.withSymbolicTraits(traits) {
//                font = UIFont(descriptor: descriptorWithTraits, size: CGFloat(fontSize))
//            } else {
//                font = UIFont(name: currentFontName ?? "Arial", size: CGFloat(fontSize)) ?? UIFont.systemFont(ofSize: CGFloat(fontSize))
//            }
//
//            let fullRange = NSRange(location: 0, length: attString.length)
//            attString.beginEditing()
//            attString.setAttributes([NSAttributedString.Key.font: font], range: fullRange)
//            if isUnderline {
//                attString.addAttribute(NSAttributedString.Key.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: fullRange)
//            }
//            attString.endEditing()
//
//            return attString
//        }
//
//        return nil
//    }
//
//    // 解析图片
//    private func processImage(node: XMLNode, unzipDirectory: URL) throws -> NSTextAttachment? {
//        if let embedId = node["a:blip"].element?.attribute(by: "r:embed")?.text {
//            let mediaPath = unzipDirectory.appendingPathComponent("word/media/\(embedId)")
//            if FileManager.default.fileExists(atPath: mediaPath.path) {
//                let image = UIImage(contentsOfFile: mediaPath.path)
//                let textAttachment = NSTextAttachment()
//                textAttachment.image = image
//                return textAttachment
//            }
//        }
//        return nil
//    }
//
//    // 解析图表
//    private func processChart(node: XMLNode) -> String? {
//        // 简单地返回图表占位符描述
//        if let chartId = node.element?.attribute(by: "r:id")?.text {
//            return "[图表: \(chartId)]"
//        }
//        return "[未知图表]"
//    }
//}
//



//import Foundation
//import UIKit
//import SWXMLHash
//class DocxParser {
//    typealias XMLNode = XMLIndexer
//
//    private var relationships: [String: String] = [:] // 存储超链接的 r:id 和 URL 的映射
//
//    func parseDocument(xml: XMLNode, relationships: [String: String]) throws -> NSAttributedString {
//        self.relationships = relationships // 加载关系映射（超链接等）
//
//        let bodyXML = xml["w:document"]["w:body"]
//        let paragraphs = bodyXML["w:p"].all
//
//        let docAttributedString = NSMutableAttributedString()
//
//        for paragraphXML in paragraphs {
//            let paragraphAttributedString = try parseParagraph(paragraphXML: paragraphXML)
//            docAttributedString.append(paragraphAttributedString)
//            docAttributedString.append(NSAttributedString(string: "\n")) // 换行
//        }
//
//        return docAttributedString
//    }
//
//    private func parseParagraph(paragraphXML: XMLNode) throws -> NSAttributedString {
//        let paragraphAttributedString = NSMutableAttributedString()
//        
//        for node in paragraphXML.children {
//            if let elementName = node.element?.name {
//                switch elementName {
//                case "w:r": // 文本运行
//                    if let attributedText = parseTextRun(runXML: node) {
//                        paragraphAttributedString.append(attributedText)
//                    }
//                case "w:hyperlink": // 超链接
//                    if let hyperlinkAttributedString = try parseHyperlink(hyperlinkXML: node) {
//                        paragraphAttributedString.append(hyperlinkAttributedString)
//                    }
//                default:
//                    break
//                }
//            }
//        }
//
//        return paragraphAttributedString
//    }
//
//    private func parseTextRun(runXML: XMLNode) -> NSAttributedString? {
//        guard let text = runXML["w:t"].element?.text else { return nil }
//        
//        let attributedString = NSMutableAttributedString(string: text)
//
//        // 解析样式
//        let runProperties = runXML["w:rPr"]
//        if let fontName = runProperties["w:rFonts"].element?.attribute(by: "w:ascii")?.text {
//            let fontSize = (runProperties["w:sz"].element?.attribute(by: "w:val")?.text).flatMap { Double($0) } ?? 22.0
//            let font = UIFont(name: fontName, size: CGFloat(fontSize / 2)) ?? UIFont.systemFont(ofSize: CGFloat(fontSize / 2))
//            attributedString.addAttribute(.font, value: font, range: NSRange(location: 0, length: attributedString.length))
//        }
//
//        if runProperties["w:b"].element != nil { // 加粗
//            attributedString.addAttribute(.font, value: UIFont.boldSystemFont(ofSize: 12), range: NSRange(location: 0, length: attributedString.length))
//        }
//
//        if runProperties["w:u"].element != nil { // 下划线
//            attributedString.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: NSRange(location: 0, length: attributedString.length))
//        }
//
//        return attributedString
//    }
//
//    private func parseHyperlink(hyperlinkXML: XMLNode) throws -> NSAttributedString? {
//        guard let rId = hyperlinkXML.element?.attribute(by: "r:id")?.text else { return nil }
//        guard let urlString = relationships[rId], let url = URL(string: urlString) else { return nil }
//
//        let hyperlinkAttributedString = NSMutableAttributedString()
//
//        for runXML in hyperlinkXML["w:r"].all {
//            if let attributedText = parseTextRun(runXML: runXML) {
//                hyperlinkAttributedString.append(attributedText)
//            }
//        }
//
//        // 添加超链接属性
//        let fullRange = NSRange(location: 0, length: hyperlinkAttributedString.length)
//        hyperlinkAttributedString.addAttribute(.link, value: url, range: fullRange)
//
//        return hyperlinkAttributedString
//    }
//}





//import Foundation
//import Zip // Pod: 'Zip', '~> 2.1'
//import SWXMLHash // Pod: 'SWXMLHash', '~> 7.0'
//import UIKit // For NSAttributedString, UIFont, UIColor, UIImage, NSTextAttachment
//
//// MARK: - Error Handling
//enum DocParserError: Error {
//    case unzipFailed(Error)                 // 解压缩DOCX文件失败
//    case fileNotFound(String)               // 指定文件未找到 (例如 document.xml)
//    case xmlParsingFailed(Error)            // XML解析失败
//    case relationshipParsingFailed(String)  // 关系文件解析失败
//    case unsupportedFormat(String)          // 不支持的格式
//    case resourceLoadFailed(String)         // 资源加载失败 (例如图片)
//    case pdfGenerationFailed(String)        // PDF生成失败
//}
//
//// MARK: - Constants and Helpers
//struct DocxConstants {
//    static let emuPerPoint: CGFloat = 12700.0     // 1 磅 (point) = 12700 EMU (English Metric Unit)
//    static let defaultFontSize: CGFloat = 12.0    // 默认字体大小（磅）
//    static let defaultFontName: String = "Times New Roman" // 常见的默认字体
//
//    // PDF 生成常量
//    static let a4PageRect = CGRect(x: 0, y: 0, width: 595.2, height: 841.8) // A4 页面尺寸 (磅) (210mm x 297mm)
//    static let defaultPDFMargins = UIEdgeInsets(top: 72, left: 72, bottom: 72, right: 72) // 默认PDF页边距 (1英寸 = 72磅)
//}
//
//// XMLIndexer 扩展，用于安全获取属性值
//extension XMLIndexer {
//    func attributeValue(by name: String) -> String? {
//        return self.element?.attribute(by: name)?.text
//    }
//}
//
//// MARK: - DocParser Class
//class DocParser {
//    typealias XMLNode = XMLIndexer
//    typealias Attributes = [NSAttributedString.Key: Any]
//
//    private var relationships: [String: String] = [:] // [Id: Target]
//    private var mediaBaseURL: URL?
//
//    // MARK: - Public Interface
//    func parseFile(fileURL: URL) throws -> NSAttributedString {
//        // 1. Unzip the DOCX file
//        let unzipDirectory: URL
//        do {
//            // Create a unique temporary directory for unzipping
//         
//            unzipDirectory = try Zip.quickUnzipFile(fileURL)
//            print("Unzipped to: \(unzipDirectory.path)")
//        } catch {
//            print("Error unzipping file: \(error)")
//            throw DocParserError.unzipFailed(error)
//        }
//
//        self.mediaBaseURL = unzipDirectory.appendingPathComponent("word", isDirectory: true)
//
//        // 2. Parse Relationships
//        let relsURL = unzipDirectory.appendingPathComponent("word/_rels/document.xml.rels")
//        if FileManager.default.fileExists(atPath: relsURL.path) {
//            try parseRelationships(relsFileURL: relsURL)
//            print("Parsed \(relationships.count) relationships.")
//        } else {
//            print("Warning: Relationship file not found at \(relsURL.path)")
//            // Continue without relationships, but some features like hyperlinks/images might fail
//        }
//
//        // 3. Parse Main Document
//        let mainDocumentURL = unzipDirectory.appendingPathComponent("word/document.xml")
//        guard FileManager.default.fileExists(atPath: mainDocumentURL.path) else {
//            throw DocParserError.fileNotFound("word/document.xml")
//        }
//        print("Parsing main document: \(mainDocumentURL.path)")
//
//        let xmlString: String
//        let xml: XMLNode
//        do {
//            xmlString = try String(contentsOf: mainDocumentURL, encoding: .utf8)
//            xml = XMLHash.parse(xmlString)
//        } catch {
//            print("Error reading or parsing main document XML: \(error)")
//            throw DocParserError.xmlParsingFailed(error)
//        }
//        
//        // 4. Process XML to NSAttributedString
//        let attributedString = try processBody(xml: xml["w:document"]["w:body"])
//
//        // 5. Clean up temporary directory (optional, depends on lifecycle)
//         // try? FileManager.default.removeItem(at: unzipDirectory)
//         // print("Cleaned up temporary directory: \(unzipDirectory.path)")
//        
//        return attributedString
//    }
//
//    // MARK: - Relationship Parsing
//    private func parseRelationships(relsFileURL: URL) throws {
//        relationships = [:]
//        do {
//            let xmlString = try String(contentsOf: relsFileURL, encoding: .utf8)
//            let xml = XMLHash.parse(xmlString)
//            for element in xml["Relationships"]["Relationship"].all {
//                if let id = element.attributeValue(by: "Id"),
//                   let target = element.attributeValue(by: "Target") {
//                    relationships[id] = target
//                }
//            }
//        } catch {
//            print("Error parsing relationships: \(error)")
//            throw DocParserError.relationshipParsingFailed(error.localizedDescription)
//        }
//    }
//
//    // MARK: - Main Body Processing
//    private func processBody(xml: XMLNode) throws -> NSAttributedString {
//        let finalAttributedString = NSMutableAttributedString()
//
//        for element in xml.children {
//            if element.element?.name == "w:p" { // Paragraph
//                print("Processing Paragraph...")
//                let paragraphString = try processParagraph(paragraphXML: element)
//                finalAttributedString.append(paragraphString)
//                finalAttributedString.append(NSAttributedString(string: "\n")) // Add newline after each paragraph
//            } else if element.element?.name == "w:tbl" { // Table
//                 print("Processing Table...")
//                 let tableString = try processTable(tableXML: element)
//                 finalAttributedString.append(tableString)
//                 finalAttributedString.append(NSAttributedString(string: "\n")) // Add newline after table representation
//             } else if element.element?.name == "w:sectPr" {
//                 // Section properties - could be used for page setup later
//                 print("Skipping Section Properties (w:sectPr)")
//             } else if element.element?.name == "w:sdt" {
//                 // Structured Document Tag - process content within it
//                 print("Processing Structured Document Tag (w:sdt)...")
//                 let sdtContent = element["w:sdtContent"]
//                 let contentString = try processBody(xml: sdtContent) // Recursively process content
//                 finalAttributedString.append(contentString)
//             } else {
//                 print("Skipping unknown body element: \(element.element?.name ?? "nil")")
//             }
//        }
//        // Remove the last added newline if it exists and the string isn't empty
//        if finalAttributedString.length > 0 && finalAttributedString.mutableString.hasSuffix("\n") {
//            finalAttributedString.deleteCharacters(in: NSRange(location: finalAttributedString.length - 1, length: 1))
//        }
//        
//        return finalAttributedString
//    }
//    
//    // MARK: - Table Processing (Basic Text Extraction)
//    private func processTable(tableXML: XMLNode) throws -> NSAttributedString {
//        let tableAttributedString = NSMutableAttributedString()
//        print("Parsing table...")
//        for row in tableXML["w:tr"].all {
//            for cell in row["w:tc"].all {
//                // Process content within the cell (paragraphs, etc.)
//                for contentElement in cell.children {
//                     if contentElement.element?.name == "w:p" {
//                         let paraString = try processParagraph(paragraphXML: contentElement)
//                         // Remove trailing newline from paragraph before adding tab
//                         if paraString.length > 0 && paraString.string.hasSuffix("\n") {
//                             tableAttributedString.append(paraString.attributedSubstring(from: NSRange(location: 0, length: paraString.length - 1)))
//                         } else {
//                             tableAttributedString.append(paraString)
//                         }
//                     }
//                     // Add handling for other potential content within cells if needed
//                }
//                tableAttributedString.append(NSAttributedString(string: "\t")) // Add tab between cells
//            }
//            // Remove the last tab added for the row
//            if tableAttributedString.length > 0 && tableAttributedString.mutableString.hasSuffix("\t") {
//                tableAttributedString.deleteCharacters(in: NSRange(location: tableAttributedString.length - 1, length: 1))
//            }
//            tableAttributedString.append(NSAttributedString(string: "\n")) // Add newline after each row
//        }
//        // Remove the last newline added for the table
//         if tableAttributedString.length > 0 && tableAttributedString.mutableString.hasSuffix("\n") {
//             tableAttributedString.deleteCharacters(in: NSRange(location: tableAttributedString.length - 1, length: 1))
//         }
//        return tableAttributedString
//    }
//
//    // MARK: - Paragraph Processing
//    private func processParagraph(paragraphXML: XMLNode) throws -> NSAttributedString {
//        let paragraphAttributedString = NSMutableAttributedString()
//        let paragraphProperties = parseParagraphProperties(paraPropertyXML: paragraphXML["w:pPr"])
//
//        // Check for list item properties
//        var listItemPrefix = ""
//        let numPrIndexer = paragraphXML["w:pPr"]["w:numPr"]
//        if numPrIndexer.element != nil {
//            let level = numPrIndexer["w:ilvl"].attributeValue(by: "w:val").flatMap { Int($0) } ?? 0
//            // Basic indentation/prefix for list items (simplistic)
//            listItemPrefix = String(repeating: "  ", count: level + 1) + "- " // Example: "- ", "  - ", "    - "
//            // Full list formatting requires parsing numbering.xml, which is complex.
//        }
//        if !listItemPrefix.isEmpty {
//            paragraphAttributedString.append(NSAttributedString(string: listItemPrefix, attributes: paragraphProperties.runAttributes))
//        }
//
//
//        // Process runs, hyperlinks, drawings, etc. within the paragraph
//        for node in paragraphXML.children {
//            if node.element?.name == "w:r" { // Run
//                if let runString = try processRun(runXML: node, paraProps: paragraphProperties) {
//                    paragraphAttributedString.append(runString)
//                }
//            } else if node.element?.name == "w:hyperlink" { // Hyperlink
//                if let linkString = try processHyperlink(hyperlinkXML: node, paraProps: paragraphProperties) {
//                    paragraphAttributedString.append(linkString)
//                }
//            } else if node.element?.name == "w:drawing" || node.element?.name == "w:pict" { // Drawing (Image) or Picture
//                if let imageString = try processDrawing(drawingXML: node) {
//                    paragraphAttributedString.append(imageString)
//                }
//            } else if node.element?.name == "w:sym" { // Symbol
//                 if let char = node.attributeValue(by: "w:char"),
//                    let font = node.attributeValue(by: "w:font") {
//                     // Attempt to render symbol using specified font if possible, or use placeholder
//                     // This requires mapping Wingdings etc. - complex. Using placeholder for now.
//                     let symbolString = NSAttributedString(string: "[\(font) Symbol: \(char)]", attributes: paragraphProperties.runAttributes)
//                     paragraphAttributedString.append(symbolString)
//                 }
//            } else if node.element?.name == "w:tab" { // Explicit Tab character
//                 paragraphAttributedString.append(NSAttributedString(string: "\t", attributes: paragraphProperties.runAttributes)) // Use paragraph's default run attributes
//            } else if node.element?.name == "w:br" { // Line break within paragraph
//                 paragraphAttributedString.append(NSAttributedString(string: "\n", attributes: paragraphProperties.runAttributes)) // Use paragraph's default run attributes
//             } else if node.element?.name == "w:smartTag" || node.element?.name == "w:proofErr" {
//                 // Process content within smart tags or ignore proofing errors
//                 for child in node.children {
//                     if child.element?.name == "w:r" {
//                         if let runString = try processRun(runXML: child, paraProps: paragraphProperties) {
//                             paragraphAttributedString.append(runString)
//                         }
//                     }
//                     // Handle other potential nested elements if necessary
//                 }
//             }
//            // Ignore paragraph properties element <w:pPr> here
//            else if node.element?.name != "w:pPr" {
//                 print("Skipping unknown paragraph child element: \(node.element?.name ?? "nil")")
//            }
//        }
//
//        // Apply paragraph style attributes (alignment, spacing, indentation) to the entire paragraph
//        if paragraphAttributedString.length > 0 {
//            paragraphAttributedString.addAttributes(paragraphProperties.paragraphAttributes, range: NSRange(location: 0, length: paragraphAttributedString.length))
//        }
//
//        return paragraphAttributedString
//    }
//
//    // MARK: - Paragraph Property Parsing
//    private func parseParagraphProperties(paraPropertyXML: XMLNode) -> (paragraphAttributes: Attributes, runAttributes: Attributes) {
//        var paragraphAttributes: Attributes = [:]
//        var defaultRunAttributes: Attributes = [:] // Default attributes for runs in this paragraph if not overridden
//        
//        let paragraphStyle = NSMutableParagraphStyle()
//        var alignment: NSTextAlignment = .left // Default
//        var leftIndent: CGFloat = 0
//        var firstLineIndent: CGFloat = 0
//        var rightIndent: CGFloat = 0
//        var spacingBefore: CGFloat = 0
//        var spacingAfter: CGFloat = 0
//        var lineSpacingMultiple: CGFloat = 1.0 // Default single spacing
//        var lineSpacingValue: CGFloat = 0 // Actual value if specified by 'line'
//
//        // Alignment
//        if let align = paraPropertyXML["w:jc"].attributeValue(by: "w:val") {
//            switch align {
//            case "left": alignment = .left
//            case "right": alignment = .right
//            case "center": alignment = .center
//            case "both": alignment = .justified // "both" usually means justified
//            case "distribute": alignment = .justified // Treat distribute as justified
//            default: alignment = .left
//            }
//        }
//        paragraphStyle.alignment = alignment
//
//        // Indentation (Twips to Points: 1 Point = 20 Twips)
//        let twipsPerPoint: CGFloat = 20.0
//        let ind = paraPropertyXML["w:ind"]
//        if ind.element != nil {
//            if let left = ind.element?.attribute(by: "w:left")?.text ?? ind.element?.attribute(by: "w:start")?.text,
//               let val =  Double(left), val > 0 {
//                leftIndent = CGFloat(val) / twipsPerPoint
//            }
//            if let right = ind.element?.attribute(by: "w:right")?.text ?? ind.element?.attribute(by: "w:end")?.text,
//               let val = Double(right), val > 0 {
//                 rightIndent = CGFloat(val) / twipsPerPoint // Note: NSParagraphStyle doesn't have direct rightIndent, influences wrapping
//             }
//            if let firstLine = ind.element?.attribute(by: "w:firstLine")?.text,
//               let val =  Double(firstLine), val > 0 {
//                 firstLineIndent = CGFloat(val) / twipsPerPoint // Positive value
//            } else if let hanging = ind.element?.attribute(by: "w:hanging")?.text,
//                      let val = Double(hanging), val > 0  {
//                 firstLineIndent = -CGFloat(val) / twipsPerPoint // Negative value for hanging indent
//             }
//        }
//        paragraphStyle.firstLineHeadIndent = leftIndent + firstLineIndent
//        paragraphStyle.headIndent = leftIndent
//        // paragraphStyle.tailIndent = -rightIndent // Negative value indicates distance from right margin
//
//        // Spacing (Twips to Points)
//        if let spacing = paraPropertyXML["w:spacing"].element {
//            if let before = spacing.attribute(by: "w:before")?.text,
//               let val = Double(before), val > 0  {
//                spacingBefore = CGFloat(val) / twipsPerPoint
//            }
//            if let after = spacing.attribute(by: "w:after")?.text,
//               let val = Double(after), val > 0 {
//                spacingAfter = CGFloat(val) / twipsPerPoint
//            }
//             if let lineRule = spacing.attribute(by: "w:lineRule")?.text,
//                let lineValStr = spacing.attribute(by: "w:line")?.text,
//                let lineVal = Double(lineValStr) {
//                 switch lineRule {
//                 case "auto": // Expressed in 240ths of a line
//                      lineSpacingMultiple = CGFloat(lineVal) / 240.0
//                 case "exact": // Value is in twips
//                      lineSpacingValue = CGFloat(lineVal) / twipsPerPoint
//                      paragraphStyle.minimumLineHeight = lineSpacingValue
//                      paragraphStyle.maximumLineHeight = lineSpacingValue
//                      lineSpacingMultiple = 0 // Indicate exact spacing is used
//                 case "atLeast": // Value is in twips
//                      lineSpacingValue = CGFloat(lineVal) / twipsPerPoint
//                      paragraphStyle.minimumLineHeight = lineSpacingValue
//                      lineSpacingMultiple = 0 // Indicate 'atLeast' spacing is used
//                 default: break // Includes "multiple" case handled by lineSpacingMultiple directly
//                 }
//             }
//        }
//        paragraphStyle.paragraphSpacingBefore = spacingBefore
//        paragraphStyle.paragraphSpacing = spacingAfter // NSParagraphStyle uses 'paragraphSpacing' for after
//        if lineSpacingMultiple > 0 {
//            paragraphStyle.lineHeightMultiple = lineSpacingMultiple
//        }
//        
//        paragraphAttributes[.paragraphStyle] = paragraphStyle
//
//        // Default Run Properties for this paragraph (can be overridden by <w:rPr>)
//        // Example: Parse <w:pPr><w:rPr>...</w:rPr></w:pPr> here if needed
//        // defaultRunAttributes = parseRunProperties(runPropertyXML: paraPropertyXML["w:rPr"])
//
//        return (paragraphAttributes, defaultRunAttributes)
//    }
//
//    // MARK: - Run Processing
//    private func processRun(runXML: XMLNode, paraProps: (paragraphAttributes: Attributes, runAttributes: Attributes)) throws -> NSAttributedString? {
//        let runAttributedString = NSMutableAttributedString()
//        var runAttributes = paraProps.runAttributes // Start with paragraph defaults
//
//        // Parse specific run properties, potentially overriding paragraph run defaults
//        let currentRunAttributes = parseRunProperties(runPropertyXML: runXML["w:rPr"])
//        runAttributes.merge(currentRunAttributes) { (_, new) in new } // Merge, letting run-specific props override
//
//        // Process elements within the run
//        for node in runXML.children {
//             if node.element?.name == "w:t" { // Text
//                 // Check for xml:space="preserve"
//                 let text = node.element?.text ?? ""
//                 if node.attributeValue(by: "xml:space") == "preserve" {
//                     runAttributedString.append(NSAttributedString(string: text, attributes: runAttributes))
//                 } else {
//                     // Trim leading/trailing whitespace if not preserving (standard behavior)
//                     runAttributedString.append(NSAttributedString(string: text.trimmingCharacters(in: .whitespacesAndNewlines), attributes: runAttributes))
//                 }
//             } else if node.element?.name == "w:tab" { // Tab
//                  runAttributedString.append(NSAttributedString(string: "\t", attributes: runAttributes))
//             } else if node.element?.name == "w:br" { // Line break
//                 // Check break type if needed (e.g., page break, column break)
//                 // Simple line break:
//                 runAttributedString.append(NSAttributedString(string: "\n", attributes: runAttributes))
//             } else if node.element?.name == "w:drawing" || node.element?.name == "w:pict" { // Embedded drawing/picture within a run
//                 if let imageString = try processDrawing(drawingXML: node) {
//                     runAttributedString.append(imageString)
//                 }
//             } else if node.element?.name == "w:instrText" { // Field code text - often hidden, display placeholder
//                 let text = node.element?.text ?? "[Field Code]"
//                 runAttributedString.append(NSAttributedString(string: text, attributes: runAttributes))
//             } else if node.element?.name == "w:noBreakHyphen" { // Non-breaking hyphen
//                 runAttributedString.append(NSAttributedString(string: "\u{2011}", attributes: runAttributes)) // U+2011 NON-BREAKING HYPHEN
//             }
//             // Ignore run properties element <w:rPr> here
//             else if node.element?.name != "w:rPr" {
//                 print("Skipping unknown run child element: \(node.element?.name ?? "nil")")
//             }
//        }
//        
//        return runAttributedString.length > 0 ? runAttributedString : nil
//    }
//
//    // MARK: - Run Property Parsing
//    private func parseRunProperties(runPropertyXML: XMLNode) -> Attributes {
//        var attributes: Attributes = [:]
//        var fontSize = DocxConstants.defaultFontSize // Start with default
//        var fontName: String? = nil
//        var isBold = false
//        var isItalic = false
//        var isUnderline = false
//        var isStrikethrough = false
//        var isDoubleStrikethrough = false // Less common
//        var foregroundColor = UIColor.black // Default color
//        var highlightColor: UIColor? = nil
//        var verticalAlign: Int = 0 // 0: baseline, 1: superscript, 2: subscript
//
//       
//        // 字号（半点转为磅）
//        if let sz = runPropertyXML["w:sz"].attributeValue(by: "w:val"), let sizeVal = Double(sz), sizeVal > 0 {
//            // 从半点转换为磅
//            fontSize = CGFloat(sizeVal) / 2.0
//        } else if let szCs = runPropertyXML["w:szCs"].attributeValue(by: "w:val"), let sizeValCs = Double(szCs), sizeValCs > 0 {
//            // 复杂脚本的字体大小
//            fontSize = CGFloat(sizeValCs) / 2.0
//        } else {
//            // 处理错误（可以设置默认字号）
//            fontSize = 12.0 // 设置默认字号，可以根据需要调整
//        }
//
//        
//        
//        
//
//        // Font Name (Check multiple possibilities: ASCII, High ANSI, Complex Script, East Asian)
//        let rFonts = runPropertyXML["w:rFonts"]
//        fontName = rFonts.attributeValue(by: "w:ascii")
//            ?? rFonts.attributeValue(by: "w:hAnsi")
//            ?? rFonts.attributeValue(by: "w:cs") // Complex Script
//            ?? rFonts.attributeValue(by: "w:eastAsia")
//            ?? DocxConstants.defaultFontName // Fallback if none specified
//
//        // Bold
//        // Can be <w:b/> (true) or <w:b w:val="false"/> (false) or <w:b w:val="true"/>
//        if let bNode = runPropertyXML["w:b"].element {
//            isBold = bNode.attribute(by: "w:val")?.text != "false" && bNode.attribute(by: "w:val")?.text != "0"
//        } else if let bCsNode = runPropertyXML["w:bCs"].element { // Bold for Complex Script
//             isBold = bCsNode.attribute(by: "w:val")?.text != "false" && bCsNode.attribute(by: "w:val")?.text != "0"
//         }
//
//
//        // Italic
//        if let iNode = runPropertyXML["w:i"].element {
//            isItalic = iNode.attribute(by: "w:val")?.text != "false" && iNode.attribute(by: "w:val")?.text != "0"
//        } else if let iCsNode = runPropertyXML["w:iCs"].element { // Italic for Complex Script
//             isItalic = iCsNode.attribute(by: "w:val")?.text != "false" && iCsNode.attribute(by: "w:val")?.text != "0"
//         }
//
//        // Underline
//        // <w:u w:val="single"/>, <w:u w:val="none"/> etc.
//        if let uNode = runPropertyXML["w:u"].element, uNode.attribute(by: "w:val")?.text != "none" {
//            // TODO: Could map different underline styles (single, double, wave, etc.)
//            // For now, any underline other than "none" is treated as single
//             if uNode.attribute(by: "w:val")?.text != "0" { // Ensure val="0" also means no underline
//                 isUnderline = true
//             }
//        }
//        
//        // Strikethrough
//        if let strikeNode = runPropertyXML["w:strike"].element {
//             isStrikethrough = strikeNode.attribute(by: "w:val")?.text != "false" && strikeNode.attribute(by: "w:val")?.text != "0"
//         }
//         if let dstrikeNode = runPropertyXML["w:dstrike"].element { // Double Strikethrough
//             isDoubleStrikethrough = dstrikeNode.attribute(by: "w:val")?.text != "false" && dstrikeNode.attribute(by: "w:val")?.text != "0"
//             if isDoubleStrikethrough { isStrikethrough = true } // Treat double as single for simplicity now
//         }
//
//
//        // Color (Hex value "RRGGBB")
//        if let colorVal = runPropertyXML["w:color"].attributeValue(by: "w:val"), colorVal != "auto" {
//            foregroundColor = UIColor(hex: colorVal) ?? .black
//        }
//        
//        // Highlight Color
//         if let highlightVal = runPropertyXML["w:highlight"].attributeValue(by: "w:val"), highlightVal != "none" {
//             highlightColor = mapHighlightColor(highlightVal)
//         }
//
//        // Vertical Alignment (Superscript/Subscript)
//        if let vertAlign = runPropertyXML["w:vertAlign"].attributeValue(by: "w:val") {
//            switch vertAlign {
//            case "superscript": verticalAlign = 1
//            case "subscript": verticalAlign = 2
//            default: verticalAlign = 0
//            }
//        }
//
//        // Construct Font
//        var traits: UIFontDescriptor.SymbolicTraits = []
//        if isBold { traits.insert(.traitBold) }
//        if isItalic { traits.insert(.traitItalic) }
//
//        var finalFont: UIFont?
//        if let baseFont = UIFont(name: fontName ?? DocxConstants.defaultFontName, size: fontSize) {
//            if let fontDescriptor = baseFont.fontDescriptor.withSymbolicTraits(traits) {
//                finalFont = UIFont(descriptor: fontDescriptor, size: fontSize)
//            } else {
//                finalFont = baseFont // Use base font if traits couldn't be applied
//            }
//        } else {
//             // Fallback if font name is invalid
//             print("Warning: Font '\(fontName ?? "nil")' not found. Falling back to system font.")
//             let systemFont = UIFont.systemFont(ofSize: fontSize)
//             if let descriptor = systemFont.fontDescriptor.withSymbolicTraits(traits) {
//                 finalFont = UIFont(descriptor: descriptor, size: fontSize)
//             } else {
//                 finalFont = systemFont
//             }
//        }
//
//
//        // Apply Attributes
//        if let font = finalFont {
//            attributes[.font] = font
//        }
//        attributes[.foregroundColor] = foregroundColor
//        if isUnderline {
//            attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
//             // attributes[.underlineColor] = foregroundColor // Optionally set underline color
//        }
//        if isStrikethrough {
//             attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
//             // attributes[.strikethroughColor] = foregroundColor // Optionally set strikethrough color
//         }
//        if let bgColor = highlightColor {
//             attributes[.backgroundColor] = bgColor
//         }
//        if verticalAlign != 0 {
//            attributes[.baselineOffset] = (verticalAlign == 1) ? (fontSize * 0.3) : -(fontSize * 0.2) // Adjust baseline offset factor as needed
//            // Reduce font size slightly for super/subscript for better appearance
//            if let smallerFont = finalFont?.withSize(fontSize * 0.75) {
//                attributes[.font] = smallerFont
//            }
//        }
//
//        return attributes
//    }
//    
//    // MARK: - Hyperlink Processing
//    private func processHyperlink(hyperlinkXML: XMLNode, paraProps: (paragraphAttributes: Attributes, runAttributes: Attributes)) throws -> NSAttributedString? {
//        guard let relationshipId = hyperlinkXML.attributeValue(by: "r:id"),
//              let targetPath = relationships[relationshipId] else {
//            // If no ID or target, just process the contained runs as normal text
//             print("Warning: Hyperlink found without valid r:id or target in relationships. Processing as text.")
//             let runsAttributedString = NSMutableAttributedString()
//             for runNode in hyperlinkXML["w:r"].all {
//                  if let runString = try processRun(runXML: runNode, paraProps: paraProps) {
//                      runsAttributedString.append(runString)
//                  }
//             }
//             return runsAttributedString.length > 0 ? runsAttributedString : nil
//        }
//        
//        var linkURL: URL?
//        // Check if the target is an external URL or an internal anchor
//        if targetPath.starts(with: "http://") || targetPath.starts(with: "https://") || targetPath.starts(with: "mailto:") {
//             linkURL = URL(string: targetPath)
//        } else if let anchor = hyperlinkXML.attributeValue(by: "w:anchor") {
//             // Internal bookmark link - NSAttributedString doesn't directly support this well without custom handling
//             print("Internal anchor link detected: \(anchor). Target: \(targetPath). Treating as text.")
//             // Could potentially create a custom attribute or use a placeholder URL scheme.
//        } else {
//            // Could be a relative path to another file - handle if necessary
//             print("Unhandled hyperlink target: \(targetPath). Treating as text.")
//        }
//
//        // Process the runs within the hyperlink to get the display text and style
//        let hyperlinkContent = NSMutableAttributedString()
//        for runNode in hyperlinkXML["w:r"].all {
//            if let runString = try processRun(runXML: runNode, paraProps: paraProps) {
//                hyperlinkContent.append(runString)
//            }
//        }
//
//        // Apply the link attribute if a valid URL was found
//        if let url = linkURL, hyperlinkContent.length > 0 {
//             // Add default blue color and underline if not already specified by run styles
//             let defaultLinkAttributes: Attributes = [
//                 .foregroundColor: UIColor.blue,
//                 .underlineStyle: NSUnderlineStyle.single.rawValue
//             ]
//             hyperlinkContent.enumerateAttributes(in: NSRange(0..<hyperlinkContent.length), options: []) { attrs, range, _ in
//                 var needsDefaultStyle = true
//                 if let _ = attrs[.foregroundColor] { // If color is explicitly set, keep it
//                      // No need to check specific color, assume explicit means desired
//                 } else {
//                      hyperlinkContent.addAttribute(.foregroundColor, value: UIColor.blue, range: range)
//                 }
//                 if let _ = attrs[.underlineStyle] { // If underline is explicitly set (even none), keep it
//                      // No need to check specific style, assume explicit means desired
//                 } else {
//                     hyperlinkContent.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
//                 }
//             }
//             
//             hyperlinkContent.addAttribute(.link, value: url, range: NSRange(location: 0, length: hyperlinkContent.length))
//        } else {
//            // If no valid URL, return the styled text without the link attribute
//            print("Warning: Could not create valid URL for hyperlink r:id \(relationshipId) -> \(targetPath)")
//        }
//        
//        return hyperlinkContent.length > 0 ? hyperlinkContent : nil
//    }
//
//    // MARK: - Drawing (Image) Processing
//    private func processDrawing(drawingXML: XMLNode) throws -> NSAttributedString? {
//        // Look for image data embed reference in different possible paths
//        // Common paths: w:drawing/wp:inline/a:graphic/a:graphicData/pic:pic/pic:blipFill/a:blip
//        //             or w:drawing/wp:anchor/a:graphic/a:graphicData/pic:pic/pic:blipFill/a:blip
//        //             or w:pict/v:shape/v:imagedata
//        
//        var embedId: String? = nil
//        var extentX: CGFloat? = nil // Width in EMU
//        var extentY: CGFloat? = nil // Height in EMU
//
//        if let blip = drawingXML.deepSearch(elements: ["a:blip"]).first {
//             embedId = blip.attributeValue(by: "r:embed")
//             // Try to find extent in the inline or anchor path
//             if let extent = drawingXML.deepSearch(elements: ["wp:extent"]).first {
//                 extentX = (extent.attributeValue(by: "cx") as NSString?)?.doubleValue as? CGFloat ?? 0
//                 extentY = (extent.attributeValue(by: "cy") as NSString?)?.doubleValue as? CGFloat ?? 0
//             }
//        } else if let imageData = drawingXML.deepSearch(elements: ["v:imagedata"]).first {
//            // VML image format (older)
//            embedId = imageData.attributeValue(by: "r:id")
//            // VML uses 'style' or width/height attributes for size - more complex parsing
//            print("VML image detected (v:imagedata) - size parsing not fully implemented.")
//            if let style = drawingXML.deepSearch(elements: ["v:shape"]).first?.attributeValue(by: "style") {
//                // Basic parsing of style="width:..pt;height:..pt"
//                if let widthStr = style.extractValue(forKey: "width", unit: "pt") { extentX = widthStr * DocxConstants.emuPerPoint }
//                if let heightStr = style.extractValue(forKey: "height", unit: "pt") { extentY = heightStr * DocxConstants.emuPerPoint }
//            }
//        }
//
//
//        guard let id = embedId,
//              let imageRelativePath = relationships[id],
//              let base = mediaBaseURL else {
//            print("Warning: Image found, but couldn't find embed ID (\(embedId ?? "nil")) or relationship or media base URL.")
//            return NSAttributedString(string: "[Image: Missing Reference]")
//        }
//
//        // Construct the full path to the image file
//        // Target path might be relative like "media/image1.png"
//        let imageURL = base.appendingPathComponent(imageRelativePath)
//        
//        guard FileManager.default.fileExists(atPath: imageURL.path) else {
//            print("Warning: Image file not found at expected path: \(imageURL.path)")
//            return NSAttributedString(string: "[Image: File Not Found at \(imageRelativePath)]")
//        }
//
//        if let image = UIImage(contentsOfFile: imageURL.path) {
//            let textAttachment = NSTextAttachment()
//            textAttachment.image = image
//
//            // Set bounds based on XML dimensions if available, otherwise use image intrinsic size
//             if let cx = extentX, let cy = extentY, cx > 0, cy > 0 {
//                 let widthInPoints = cx / DocxConstants.emuPerPoint
//                 let heightInPoints = cy / DocxConstants.emuPerPoint
//                 // Maintain aspect ratio based on width if height seems wrong or vice-versa? For now, use both.
//                 textAttachment.bounds = CGRect(x: 0, y: 0, width: widthInPoints, height: heightInPoints)
//                 print("Image \(imageRelativePath): Applying size \(widthInPoints)x\(heightInPoints) points")
//             } else {
//                  print("Image \(imageRelativePath): Using intrinsic size \(image.size)")
//                 // Optional: Constrain max width/height if needed
//                 // textAttachment.bounds = CGRect(origin: .zero, size: image.size)
//             }
//
//            return NSAttributedString(attachment: textAttachment)
//        } else {
//             print("Warning: Failed to load image from path: \(imageURL.path)")
//             return NSAttributedString(string: "[Image: Load Failed at \(imageRelativePath)]")
//        }
//    }
//    
//    // MARK: - Chart Processing (Placeholder)
//     // Included from original code for completeness, but remains a placeholder
//    private func processChart(node: XMLNode) -> String? {
//         // Simple placeholder based on relationship ID
//         if let chartId = node.attributeValue(by: "r:id") {
//             let target = relationships[chartId] ?? "Unknown Target"
//             print("Chart detected: r:id=\(chartId), Target=\(target). Using placeholder.")
//             return "[Chart: \(chartId)]"
//         }
//         return "[Unknown Chart]"
//     }
//
//    // MARK: - Helper Functions
//    
//    // Maps standard OOXML highlight color names to UIColors
//    private func mapHighlightColor(_ value: String) -> UIColor? {
//         switch value.lowercased() {
//             case "black": return UIColor(white: 0.2, alpha: 0.5) // Use semi-transparent grey for black highlight?
//             case "blue": return UIColor.blue.withAlphaComponent(0.3)
//             case "cyan": return UIColor.cyan.withAlphaComponent(0.3)
//             case "green": return UIColor.green.withAlphaComponent(0.3)
//             case "magenta": return UIColor.magenta.withAlphaComponent(0.3)
//             case "red": return UIColor.red.withAlphaComponent(0.3)
//             case "yellow": return UIColor.yellow.withAlphaComponent(0.5) // Yellow often stronger
//             case "white": return UIColor(white: 0.9, alpha: 0.5) // Light grey for white?
//             case "darkblue": return UIColor.blue.withAlphaComponent(0.5) // Darker alpha
//             case "darkcyan": return UIColor.cyan.withAlphaComponent(0.5)
//             case "darkgreen": return UIColor.green.withAlphaComponent(0.5)
//             case "darkmagenta": return UIColor.magenta.withAlphaComponent(0.5)
//             case "darkred": return UIColor.red.withAlphaComponent(0.5)
//             case "darkyellow": return UIColor.yellow.withAlphaComponent(0.7)
//             case "darkgray": return UIColor.darkGray.withAlphaComponent(0.5)
//             case "lightgray": return UIColor.lightGray.withAlphaComponent(0.5)
//             case "none": return nil
//             default: return nil // Unknown color
//         }
//     }
//}
//
//// MARK: - UIColor Hex Initializer
//extension UIColor {
//    convenience init?(hex: String) {
//        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
//        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
//
//        var rgb: UInt64 = 0
//
//        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else {
//            return nil
//        }
//
//        let length = hexSanitized.count
//        let r, g, b: CGFloat
//        if length == 6 {
//            r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
//            g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
//            b = CGFloat(rgb & 0x0000FF) / 255.0
//        } else {
//            // Could add support for 3-digit hex or alpha hex if needed
//            return nil // Only support RRGGBB for now
//        }
//
//        self.init(red: r, green: g, blue: b, alpha: 1.0)
//    }
//}
//
//// MARK: - XMLIndexer Deep Search Helper
//extension XMLIndexer {
//    // Performs a breadth-first search for elements with matching names
//    func deepSearch(elements names: [String]) -> [XMLIndexer] {
//        var results: [XMLIndexer] = []
//        var queue: [XMLIndexer] = [self]
//
//        while !queue.isEmpty {
//            let current = queue.removeFirst()
//            if let elementName = current.element?.name, names.contains(elementName) {
//                results.append(current)
//            }
//            // Add children to the queue for further searching
//            queue.append(contentsOf: current.children)
//        }
//        return results
//    }
//}
//
//
//// MARK: - String Extension for VML Style Parsing (Basic)
//extension String {
//    func extractValue(forKey key: String, unit: String) -> CGFloat? {
//        let pattern = "\(key):\\s*([0-9.]+)\\s*\(unit)"
//        if let range = self.range(of: pattern, options: [.regularExpression, .caseInsensitive]),
//           let valueString = self.substring(with: range).matches(for: pattern).first?.last, // Get captured group
//           let value = Double(valueString) {
//            return CGFloat(value)
//        }
//        return nil
//    }
//
//    // Helper to get captured groups from regex match
//    func matches(for regex: String) -> [[String]] {
//        do {
//            let regex = try NSRegularExpression(pattern: regex)
//            let results = regex.matches(in: self, range: NSRange(self.startIndex..., in: self))
//            return results.map { result in
//                return (0..<result.numberOfRanges).map {
//                    result.range(at: $0).location != NSNotFound
//                        ? String(self[Range(result.range(at: $0), in: self)!])
//                        : ""
//                }
//            }
//        } catch {
//            print("Invalid regex: \(error.localizedDescription)")
//            return []
//        }
//    }
//     // Helper to get substring from NSRange
//     func substring(with nsrange: NSRange) -> String? {
//         guard let range = Range(nsrange, in: self) else { return nil }
//         return String(self[range])
//     }
//}



//    func generatePDF(
//        from attributedString: NSAttributedString,
//        pageRect: CGRect = DocxConstants.a4PageRect,
//        margins: UIEdgeInsets = DocxConstants.defaultPDFMargins,
//        saveToURL: URL? = nil
//    ) throws -> Data {
//        let pdfData = NSMutableData()
//
//        // 开始 PDF 上下文
//        UIGraphicsBeginPDFContextToData(pdfData, pageRect, nil)
//        defer { UIGraphicsEndPDFContext() } // 确保在函数退出时结束上下文
//
//        // 使用 CoreText 进行分页
//        let framesetter = CTFramesetterCreateWithAttributedString(attributedString as CFAttributedString)
//        var currentRange = CFRangeMake(0, 0) // 当前已渲染的字符范围
//        var pageCount = 0
//
//        while currentRange.location + currentRange.length < attributedString.length {
//            pageCount += 1
//            UIGraphicsBeginPDFPageWithInfo(pageRect, nil) // 开始新的一页
//
//            // 计算当前页面的文本绘制区域 (减去边距)
//            let textFrameRect = CGRect(
//                x: margins.left,
//                y: margins.top,
//                width: pageRect.width - margins.left - margins.right,
//                height: pageRect.height - margins.top - margins.bottom
//            )
//
//            let path = CGMutablePath()
//            path.addRect(textFrameRect)
//
//            // 创建当前页面的 Frame
//            let frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(currentRange.location + currentRange.length, 0), path, nil)
//
//            // 获取当前 PDF 页面的图形上下文
//            guard let currentContext = UIGraphicsGetCurrentContext() else {
//                throw DocParserError.pdfGenerationFailed("无法获取当前 PDF 图形上下文 (第 \(pageCount) 页)。")
//            }
//
//            // CoreText 坐标系与 UIKit 不同，需要翻转
//            currentContext.textMatrix = .identity
//            currentContext.translateBy(x: 0, y: pageRect.height)
//            currentContext.scaleBy(x: 1.0, y: -1.0)
//
//            // 绘制 Frame 内容
//            CTFrameDraw(frame, currentContext)
//
//            // 获取已在此 Frame 中绘制的字符范围，用于下一页的起始点
//            currentRange = CTFrameGetVisibleStringRange(frame)
//
//            // 可以在这里添加页眉/页脚等
//            // 例如，绘制页码：
//            // currentContext.scaleBy(x: 1.0, y: -1.0) // 翻转回来绘制 UIKit 内容
//            // currentContext.translateBy(x: 0, y: -pageRect.height)
//            // let pageNumText = NSAttributedString(string: "第 \(pageCount) 页", attributes: [.font: UIFont.systemFont(ofSize: 10)])
//            // pageNumText.draw(at: CGPoint(x: pageRect.width - margins.right - 50, y: pageRect.height - margins.bottom + 10))
//
//        }
//
//        print("PDF 生成完毕，共 \(pageCount) 页。")
//        if let outputURL = saveToURL {
//            do {
//                try pdfData.write(to: outputURL)
//                print("PDF 已成功保存到: \(outputURL.path)")
//            } catch {
//                print("保存 PDF 文件失败: \(error)")
//                throw DocParserError.pdfSavingFailed(error)
//            }
//        }
//        return pdfData as Data
//    }


// ************************************完整可解析出来的代码1*************************
//import Foundation
//import Zip // Pod: 'Zip', '~> 2.1'
//import SWXMLHash // Pod: 'SWXMLHash', '~> 7.0'
//import UIKit // For NSAttributedString, UIFont, UIColor, UIImage, NSTextAttachment
//import CoreText // 用于PDF分页生成
//
//// MARK: - 错误处理 (Error Handling)
//enum DocParserError: Error {
//    case unzipFailed(Error)                 // 解压缩DOCX文件失败
//    case fileNotFound(String)               // 指定文件未找到 (例如 document.xml)
//    case xmlParsingFailed(Error)            // XML解析失败
//    case relationshipParsingFailed(String)  // 关系文件解析失败
//    case unsupportedFormat(String)          // 不支持的格式
//    case resourceLoadFailed(String)         // 资源加载失败 (例如图片)
//    case pdfGenerationFailed(String)        // PDF生成失败
//    case pdfSavingFailed(Error)             // PDF保存失败
//}
//
//// MARK: - 常量和辅助结构 (Constants and Helpers)
//struct DocxConstants {
//    static let emuPerPoint: CGFloat = 12700.0     // 1 磅 (point) = 12700 EMU (English Metric Unit)
//    static let defaultFontSize: CGFloat = 12.0    // 默认字体大小（磅）
//    static let defaultFontName: String = "Times New Roman" // 常见的默认字体
//
//    // PDF 生成常量
//    static let a4PageRect = CGRect(x: 0, y: 0, width: 595.2, height: 841.8) // A4 页面尺寸 (磅) (210mm x 297mm)
//    static let defaultPDFMargins = UIEdgeInsets(top: 72, left: 72, bottom: 72, right: 72) // 默认PDF页边距 (1英寸 = 72磅)
//}
//
//// XMLIndexer 扩展，用于安全获取属性值
//extension XMLIndexer {
//    func attributeValue(by name: String) -> String? {
//        return self.element?.attribute(by: name)?.text
//    }
//}
//
//// MARK: - DocParser 类 (DocParser Class)
//class DocParser {
//    typealias XMLNode = XMLIndexer
//    typealias Attributes = [NSAttributedString.Key: Any]
//
//    private var relationships: [String: String] = [:] // [关系ID: 目标路径] (例如图片、超链接的目标)
//    private var mediaBaseURL: URL?                    // 解压后 'word' 目录的URL，用于定位媒体文件
//
//    // MARK: - 公共接口 (Public Interface)
//    /**
//     * 解析指定的 DOCX 文件URL，返回一个 NSAttributedString。
//     * - Parameter fileURL: DOCX 文件的本地 URL。
//     * - Throws: DocParserError 如果解析过程中发生任何错误。
//     * - Returns: 表示文档内容的 NSAttributedString。
//     */
//    func parseFile(fileURL: URL) throws -> NSAttributedString {
//        // 1. 解压缩 DOCX 文件
//        let unzipDirectory: URL
//        do {
//            unzipDirectory = try Zip.quickUnzipFile(fileURL)
//            print("解压到: \(unzipDirectory.path)")
//        } catch {
//            print("解压文件错误: \(error)")
//            throw DocParserError.unzipFailed(error)
//        }
//
//        self.mediaBaseURL = unzipDirectory.appendingPathComponent("word", isDirectory: true)
//
//        // 2. 解析关系文件 (word/_rels/document.xml.rels)
//        let relsURL = unzipDirectory.appendingPathComponent("word/_rels/document.xml.rels")
//        if FileManager.default.fileExists(atPath: relsURL.path) {
//            try parseRelationships(relsFileURL: relsURL)
//            print("已解析 \(relationships.count) 个关系。")
//        } else {
//            print("警告: 关系文件未找到于 \(relsURL.path)")
//            // 没有关系文件也可以继续，但图片、超链接等功能可能失效
//        }
//
//        // 3. 解析主文档 (word/document.xml)
//        let mainDocumentURL = unzipDirectory.appendingPathComponent("word/document.xml")
//        guard FileManager.default.fileExists(atPath: mainDocumentURL.path) else {
//            throw DocParserError.fileNotFound("word/document.xml")
//        }
//        print("正在解析主文档: \(mainDocumentURL.path)")
//
//        let xmlString: String
//        let xml: XMLNode
//        do {
//            xmlString = try String(contentsOf: mainDocumentURL, encoding: .utf8)
//            xml = XMLHash.parse(xmlString)
//        } catch {
//            print("读取或解析主文档 XML 错误: \(error)")
//            throw DocParserError.xmlParsingFailed(error)
//        }
//        
//        // 4. 将 XML 处理为 NSAttributedString
//        let attributedString = try processBody(xml: xml["w:document"]["w:body"])
//
//        // 5. 清理临时解压目录 (可选, 取决于生命周期管理)
//        // try? FileManager.default.removeItem(at: unzipDirectory)
//        // print("已清理临时目录: \(unzipDirectory.path)")
//        
//        return attributedString
//    }
//
//    // MARK: - 关系解析 (Relationship Parsing)
//    private func parseRelationships(relsFileURL: URL) throws {
//        relationships = [:] // 重置关系字典
//        do {
//            let xmlString = try String(contentsOf: relsFileURL, encoding: .utf8)
//            let xml = XMLHash.parse(xmlString)
//            // 遍历 <Relationships> 下的每一个 <Relationship> 元素
//            for element in xml["Relationships"]["Relationship"].all {
//                if let id = element.attributeValue(by: "Id"), // 获取 Id 属性
//                   let target = element.attributeValue(by: "Target") { // 获取 Target 属性
//                    relationships[id] = target // 存储 ID 和 Target 的映射
//                }
//            }
//        } catch {
//            print("解析关系文件错误: \(error)")
//            throw DocParserError.relationshipParsingFailed(error.localizedDescription)
//        }
//    }
//
//    // MARK: - 主体内容处理 (Main Body Processing)
//    private func processBody(xml: XMLNode) throws -> NSAttributedString {
//        let finalAttributedString = NSMutableAttributedString()
//
//        // 遍历 w:body 下的所有子元素
//        for element in xml.children {
//            if element.element?.name == "w:p" { // 段落 (Paragraph)
//                print("处理段落...")
//                let paragraphString = try processParagraph(paragraphXML: element)
//                finalAttributedString.append(paragraphString)
//                finalAttributedString.append(NSAttributedString(string: "\n")) // 每个段落后添加换行符
//            } else if element.element?.name == "w:tbl" { // 表格 (Table)
//                 print("处理表格...")
//                 let tableString = try processTable(tableXML: element)
//                 finalAttributedString.append(tableString)
//                 finalAttributedString.append(NSAttributedString(string: "\n")) // 表格表示后添加换行符
//             } else if element.element?.name == "w:sectPr" { // 章节属性 (Section Properties)
//                 // 章节属性 - 之后可用于页面设置
//                 print("跳过章节属性 (w:sectPr)")
//             } else if element.element?.name == "w:sdt" { // 结构化文档标签 (Structured Document Tag)
//                 // 处理其内容
//                 print("处理结构化文档标签 (w:sdt)...")
//                 let sdtContent = element["w:sdtContent"]
//                 let contentString = try processBody(xml: sdtContent) // 递归处理内容
//                 finalAttributedString.append(contentString)
//             } else {
//                 print("跳过未知的主体元素: \(element.element?.name ?? "nil")")
//             }
//        }
//        // 如果字符串不为空且以换行符结尾，则移除最后一个换行符
//        if finalAttributedString.length > 0 && finalAttributedString.mutableString.hasSuffix("\n") {
//            finalAttributedString.deleteCharacters(in: NSRange(location: finalAttributedString.length - 1, length: 1))
//        }
//        
//        return finalAttributedString
//    }
//    
//    // MARK: - 表格处理 (Table Processing - 基础文本提取)
//    private func processTable(tableXML: XMLNode) throws -> NSAttributedString {
//        let tableAttributedString = NSMutableAttributedString()
//        print("解析表格...")
//        // 遍历表格中的每一行 <w:tr>
//        for row in tableXML["w:tr"].all {
//            // 遍历行中的每一个单元格 <w:tc>
//            for cell in row["w:tc"].all {
//                // 处理单元格内的内容 (例如段落)
//                for contentElement in cell.children {
//                     if contentElement.element?.name == "w:p" { // 如果是段落
//                         let paraString = try processParagraph(paragraphXML: contentElement)
//                         // 在添加制表符前，移除段落末尾的换行符
//                         if paraString.length > 0 && paraString.string.hasSuffix("\n") {
//                             tableAttributedString.append(paraString.attributedSubstring(from: NSRange(location: 0, length: paraString.length - 1)))
//                         } else {
//                             tableAttributedString.append(paraString)
//                         }
//                     }
//                     // 如果需要，在此处添加对单元格内其他潜在内容的处理
//                }
//                tableAttributedString.append(NSAttributedString(string: "\t")) // 单元格之间添加制表符
//            }
//            // 移除行为最后一个单元格添加的制表符
//            if tableAttributedString.length > 0 && tableAttributedString.mutableString.hasSuffix("\t") {
//                tableAttributedString.deleteCharacters(in: NSRange(location: tableAttributedString.length - 1, length: 1))
//            }
//            tableAttributedString.append(NSAttributedString(string: "\n")) // 每行结束后添加换行符
//        }
//        // 移除为表格最后一行添加的换行符
//         if tableAttributedString.length > 0 && tableAttributedString.mutableString.hasSuffix("\n") {
//             tableAttributedString.deleteCharacters(in: NSRange(location: tableAttributedString.length - 1, length: 1))
//         }
//        return tableAttributedString
//    }
//
//    // MARK: - 段落处理 (Paragraph Processing)
//    private func processParagraph(paragraphXML: XMLNode) throws -> NSAttributedString {
//        let paragraphAttributedString = NSMutableAttributedString()
//        // 解析段落属性 (对齐、缩进、间距等)
//        let paragraphProperties = parseParagraphProperties(paraPropertyXML: paragraphXML["w:pPr"])
//
//        // 检查列表项属性
//        var listItemPrefix = ""
//        let numPrIndexer = paragraphXML["w:pPr"]["w:numPr"] // 数字编号属性
//        if numPrIndexer.element != nil {
//            let level = numPrIndexer["w:ilvl"].attributeValue(by: "w:val").flatMap { Int($0) } ?? 0 // 列表级别
//            // 列表项的简单前缀/缩进 (简化处理)
//            listItemPrefix = String(repeating: "  ", count: level + 1) + "- " // 例如: "- ", "  - ", "    - "
//            // 完整的列表格式化需要解析 numbering.xml，这比较复杂。
//        }
//        if !listItemPrefix.isEmpty {
//            paragraphAttributedString.append(NSAttributedString(string: listItemPrefix, attributes: paragraphProperties.runAttributes))
//        }
//
//
//        // 处理段落内的文本运行 (run)、超链接、图像等
//        for node in paragraphXML.children {
//            if node.element?.name == "w:r" { // 文本运行 (Run)
//                if let runString = try processRun(runXML: node, paraProps: paragraphProperties) {
//                    paragraphAttributedString.append(runString)
//                }
//            } else if node.element?.name == "w:hyperlink" { // 超链接
//                if let linkString = try processHyperlink(hyperlinkXML: node, paraProps: paragraphProperties) {
//                    paragraphAttributedString.append(linkString)
//                }
//            } else if node.element?.name == "w:drawing" || node.element?.name == "w:pict" { // 图像 (Drawing or Picture)
//                if let imageString = try processDrawing(drawingXML: node) {
//                    paragraphAttributedString.append(imageString)
//                }
//            } else if node.element?.name == "w:sym" { // 符号 (Symbol)
//                 if let char = node.attributeValue(by: "w:char"), // 符号字符代码
//                    let font = node.attributeValue(by: "w:font") { // 符号字体 (如 Wingdings)
//                     // 尝试使用指定字体渲染符号，或使用占位符
//                     // 这需要映射 Wingdings 等字体 - 很复杂。暂时使用占位符。
//                     let symbolString = NSAttributedString(string: "[\(font) 符号: \(char)]", attributes: paragraphProperties.runAttributes)
//                     paragraphAttributedString.append(symbolString)
//                 }
//            } else if node.element?.name == "w:tab" { //显式制表符
//                 paragraphAttributedString.append(NSAttributedString(string: "\t", attributes: paragraphProperties.runAttributes)) // 使用段落的默认运行属性
//            } else if node.element?.name == "w:br" { // 段内换行符
//                 paragraphAttributedString.append(NSAttributedString(string: "\n", attributes: paragraphProperties.runAttributes)) // 使用段落的默认运行属性
//             } else if node.element?.name == "w:smartTag" || node.element?.name == "w:proofErr" { // 智能标签或校对错误标记
//                 // 处理智能标签内的内容或忽略校对错误
//                 for child in node.children {
//                     if child.element?.name == "w:r" { // 如果是文本运行
//                         if let runString = try processRun(runXML: child, paraProps: paragraphProperties) {
//                             paragraphAttributedString.append(runString)
//                         }
//                     }
//                     // 如果需要，处理其他可能的嵌套元素
//                 }
//             }
//            // 在此处忽略段落属性元素 <w:pPr>
//            else if node.element?.name != "w:pPr" {
//                 print("跳过未知的段落子元素: \(node.element?.name ?? "nil")")
//            }
//        }
//
//        // 将段落样式属性 (对齐、间距、缩进) 应用于整个段落
//        if paragraphAttributedString.length > 0 {
//            paragraphAttributedString.addAttributes(paragraphProperties.paragraphAttributes, range: NSRange(location: 0, length: paragraphAttributedString.length))
//        }
//
//        return paragraphAttributedString
//    }
//
//    // MARK: - 段落属性解析 (Paragraph Property Parsing)
//    private func parseParagraphProperties(paraPropertyXML: XMLNode) -> (paragraphAttributes: Attributes, runAttributes: Attributes) {
//        var paragraphAttributes: Attributes = [:] // 段落级属性 (如对齐、缩进)
//        let defaultRunAttributes: Attributes = [:] // 此段落中运行的默认属性 (如果未被覆盖)
//        
//        let paragraphStyle = NSMutableParagraphStyle()
//        var alignment: NSTextAlignment = .left // 默认左对齐
//        var leftIndent: CGFloat = 0           // 左缩进
//        var firstLineIndent: CGFloat = 0      // 首行缩进
//        var rightIndent: CGFloat = 0          // 右缩进 (NSParagraphStyle中不直接存在，影响换行)
//        var spacingBefore: CGFloat = 0        //段前间距
//        var spacingAfter: CGFloat = 0         // 段后间距
//        var lineSpacingMultiple: CGFloat = 1.0 // 默认单倍行距
//        var lineSpacingValue: CGFloat = 0      // 如果 'line' 属性指定，则为实际行距值
//
//        // 对齐方式 <w:jc w:val="...">
//        if let align = paraPropertyXML["w:jc"].attributeValue(by: "w:val") {
//            switch align {
//            case "left": alignment = .left
//            case "right": alignment = .right
//            case "center": alignment = .center
//            case "both": alignment = .justified // "both" 通常指两端对齐
//            case "distribute": alignment = .justified // "distribute" 也视为两端对齐
//            default: alignment = .left
//            }
//        }
//        paragraphStyle.alignment = alignment
//
//        // 缩进 <w:ind ...> (单位: Twips (缇) 转 Points (磅): 1 Point = 20 Twips)
//        let twipsPerPoint: CGFloat = 20.0
//        let ind = paraPropertyXML["w:ind"]
//        if ind.element != nil {
//            // 左缩进 (w:left 或 w:start)
//            if let left = ind.element?.attribute(by: "w:left")?.text ?? ind.element?.attribute(by: "w:start")?.text,
//               let val =  Double(left), val > 0 {
//                leftIndent = CGFloat(val) / twipsPerPoint
//            }
//            // 右缩进 (w:right 或 w:end)
//            if let right = ind.element?.attribute(by: "w:right")?.text ?? ind.element?.attribute(by: "w:end")?.text,
//               let val = Double(right), val > 0 {
//                 rightIndent = CGFloat(val) / twipsPerPoint
//             }
//            // 首行缩进 (w:firstLine)
//            if let firstLine = ind.element?.attribute(by: "w:firstLine")?.text,
//               let val =  Double(firstLine), val > 0 {
//                 firstLineIndent = CGFloat(val) / twipsPerPoint // 正值
//            } else if let hanging = ind.element?.attribute(by: "w:hanging")?.text, // 悬挂缩进 (w:hanging)
//                      let val = Double(hanging), val > 0  {
//                 firstLineIndent = -CGFloat(val) / twipsPerPoint // 悬挂缩进为负的首行缩进
//             }
//        }
//        paragraphStyle.firstLineHeadIndent = leftIndent + firstLineIndent // 首行头部缩进
//        paragraphStyle.headIndent = leftIndent                           // 非首行头部缩进
//        // paragraphStyle.tailIndent = -rightIndent // 尾部缩进 (负值表示距右边距的距离)
//
//        // 间距 <w:spacing ...> (单位: Twips 转 Points)
//        if let spacing = paraPropertyXML["w:spacing"].element {
//            // 段前间距 (w:before)
//            if let before = spacing.attribute(by: "w:before")?.text,
//               let val = Double(before), val > 0  {
//                spacingBefore = CGFloat(val) / twipsPerPoint
//            }
//            // 段后间距 (w:after)
//            if let after = spacing.attribute(by: "w:after")?.text,
//               let val = Double(after), val > 0 {
//                spacingAfter = CGFloat(val) / twipsPerPoint
//            }
//            // 行距 (w:lineRule, w:line)
//             if let lineRule = spacing.attribute(by: "w:lineRule")?.text, // 行距规则
//                let lineValStr = spacing.attribute(by: "w:line")?.text, // 行距值
//                let lineVal = Double(lineValStr) {
//                 switch lineRule {
//                 case "auto": // 值以行的 1/240 表示
//                      lineSpacingMultiple = CGFloat(lineVal) / 240.0
//                 case "exact": // 值单位为 Twips，固定行高
//                      lineSpacingValue = CGFloat(lineVal) / twipsPerPoint
//                      paragraphStyle.minimumLineHeight = lineSpacingValue
//                      paragraphStyle.maximumLineHeight = lineSpacingValue
//                      lineSpacingMultiple = 0 // 标记使用固定行高
//                 case "atLeast": // 值单位为 Twips，最小行高
//                      lineSpacingValue = CGFloat(lineVal) / twipsPerPoint
//                      paragraphStyle.minimumLineHeight = lineSpacingValue
//                      lineSpacingMultiple = 0 // 标记使用最小行高
//                 default: break // 包括 "multiple"，由 lineSpacingMultiple直接处理
//                 }
//             }
//        }
//        paragraphStyle.paragraphSpacingBefore = spacingBefore // 段前间距
//        paragraphStyle.paragraphSpacing = spacingAfter       // 段后间距 (NSParagraphStyle 使用 paragraphSpacing 表示段后)
//        if lineSpacingMultiple > 0 { // 如果不是固定或最小行高
//            paragraphStyle.lineHeightMultiple = lineSpacingMultiple // 设置行高倍数
//        }
//        
//        paragraphAttributes[.paragraphStyle] = paragraphStyle
//
//        // 此段落的默认运行属性 (可以被 <w:rPr> 覆盖)
//        // 例如: 在这里解析 <w:pPr><w:rPr>...</w:rPr></w:pPr> (如果需要)
//        // defaultRunAttributes = parseRunProperties(runPropertyXML: paraPropertyXML["w:rPr"])
//
//        return (paragraphAttributes, defaultRunAttributes)
//    }
//
//    // MARK: - 文本运行处理 (Run Processing)
//    private func processRun(runXML: XMLNode, paraProps: (paragraphAttributes: Attributes, runAttributes: Attributes)) throws -> NSAttributedString? {
//        let runAttributedString = NSMutableAttributedString()
//        var runAttributes = paraProps.runAttributes // 从段落默认运行属性开始
//
//        // 解析特定的运行属性，可能会覆盖段落的默认运行属性
//        let currentRunAttributes = parseRunProperties(runPropertyXML: runXML["w:rPr"])
//        runAttributes.merge(currentRunAttributes) { (_, new) in new } // 合并属性，优先使用当前 run 的特定属性
//
//        // 处理运行内的元素
//        for node in runXML.children {
//             if node.element?.name == "w:t" { // 文本内容 <w:t>
//                 let text = node.element?.text ?? ""
//                 // 检查 xml:space="preserve" 属性，以保留空格
//                 if node.attributeValue(by: "xml:space") == "preserve" {
//                     runAttributedString.append(NSAttributedString(string: text, attributes: runAttributes))
//                 } else {
//                     // 如果不保留，则修剪首尾空白字符 (标准行为)
//                     runAttributedString.append(NSAttributedString(string: text.trimmingCharacters(in: .whitespacesAndNewlines), attributes: runAttributes))
//                 }
//             } else if node.element?.name == "w:tab" { // 制表符 <w:tab/>
//                  runAttributedString.append(NSAttributedString(string: "\t", attributes: runAttributes))
//             } else if node.element?.name == "w:br" { // 换行符 <w:br/>
//                 // 如果需要，可以检查换行类型 (例如分页符、分栏符)
//                 // 简单换行:
//                 runAttributedString.append(NSAttributedString(string: "\n", attributes: runAttributes))
//             } else if node.element?.name == "w:drawing" || node.element?.name == "w:pict" { // 运行内嵌的图像
//                 if let imageString = try processDrawing(drawingXML: node) {
//                     runAttributedString.append(imageString)
//                 }
//             } else if node.element?.name == "w:instrText" { // 域代码文本 (Field Code Text) - 通常隐藏，显示占位符
//                 let text = node.element?.text ?? "[域代码]"
//                 runAttributedString.append(NSAttributedString(string: text, attributes: runAttributes))
//             } else if node.element?.name == "w:noBreakHyphen" { // 不间断连字符
//                 runAttributedString.append(NSAttributedString(string: "\u{2011}", attributes: runAttributes)) // U+2011 NON-BREAKING HYPHEN
//             }
//             // 在此处忽略运行属性元素 <w:rPr>
//             else if node.element?.name != "w:rPr" {
//                 print("跳过未知的运行子元素: \(node.element?.name ?? "nil")")
//             }
//        }
//        
//        return runAttributedString.length > 0 ? runAttributedString : nil
//    }
//
//    // MARK: - 文本运行属性解析 (Run Property Parsing)
//    private func parseRunProperties(runPropertyXML: XMLNode) -> Attributes {
//        var attributes: Attributes = [:]
//        var fontSize = DocxConstants.defaultFontSize // 从默认字号开始
//        var fontName: String? = nil                  // 字体名称
//        var isBold = false                           // 是否加粗
//        var isItalic = false                         // 是否斜体
//        var isUnderline = false                      // 是否有下划线
//        var isStrikethrough = false                  // 是否有删除线
//        var isDoubleStrikethrough = false            // 是否有双删除线 (较少见)
//        var foregroundColor = UIColor.black          // 默认文本颜色 (黑色)
//        var highlightColor: UIColor? = nil           // 高亮颜色
//        var verticalAlign: Int = 0                   // 垂直对齐: 0-基线, 1-上标, 2-下标
//
//       
//        // 字号 <w:sz w:val="..."/> (值为半点值，例如24表示12磅)
//        if let sz = runPropertyXML["w:sz"].attributeValue(by: "w:val"), let sizeVal = Double(sz), sizeVal > 0 {
//            fontSize = CGFloat(sizeVal) / 2.0 // 从半点转换为磅
//        } else if let szCs = runPropertyXML["w:szCs"].attributeValue(by: "w:val"), let sizeValCs = Double(szCs), sizeValCs > 0 {
//            // 复杂文种 (Complex Script) 的字体大小
//            fontSize = CGFloat(sizeValCs) / 2.0
//        }
//        // 如果未指定，则使用默认字号 DocxConstants.defaultFontSize
//
//        // 字体名称 <w:rFonts w:ascii="..." w:hAnsi="..." w:cs="..." w:eastAsia="..."/>
//        let rFonts = runPropertyXML["w:rFonts"]
//        fontName = rFonts.attributeValue(by: "w:ascii")       // ASCII 字符字体
//            ?? rFonts.attributeValue(by: "w:hAnsi")           // 高 ANSI 字符字体
//            ?? rFonts.attributeValue(by: "w:cs")              // 复杂文种字体
//            ?? rFonts.attributeValue(by: "w:eastAsia")        // 东亚文字字体
//            ?? DocxConstants.defaultFontName                  // 如果都未指定，则使用默认字体
//
//        // 加粗 <w:b/> 或 <w:b w:val="false"/>
//        if let bNode = runPropertyXML["w:b"].element {
//            // 如果存在 <w:b/> 标签，且 w:val 不为 "false" 或 "0"，则为粗体
//            isBold = bNode.attribute(by: "w:val")?.text != "false" && bNode.attribute(by: "w:val")?.text != "0"
//        } else if let bCsNode = runPropertyXML["w:bCs"].element { // 复杂文种的加粗
//             isBold = bCsNode.attribute(by: "w:val")?.text != "false" && bCsNode.attribute(by: "w:val")?.text != "0"
//         }
//
//        // 斜体 <w:i/> 或 <w:i w:val="false"/>
//        if let iNode = runPropertyXML["w:i"].element {
//            isItalic = iNode.attribute(by: "w:val")?.text != "false" && iNode.attribute(by: "w:val")?.text != "0"
//        } else if let iCsNode = runPropertyXML["w:iCs"].element { // 复杂文种的斜体
//             isItalic = iCsNode.attribute(by: "w:val")?.text != "false" && iCsNode.attribute(by: "w:val")?.text != "0"
//         }
//
//        // 下划线 <w:u w:val="..."/>
//        if let uNode = runPropertyXML["w:u"].element, uNode.attribute(by: "w:val")?.text != "none" {
//            // TODO: 可以映射不同的下划线样式 (single, double, wave 等)
//            // 目前，任何非 "none" 的下划线都视为单下划线
//             if uNode.attribute(by: "w:val")?.text != "0" { // 确保 val="0" 也表示无下划线
//                 isUnderline = true
//             }
//        }
//        
//        // 删除线 <w:strike/> 或 <w:strike w:val="false"/>
//        if let strikeNode = runPropertyXML["w:strike"].element {
//             isStrikethrough = strikeNode.attribute(by: "w:val")?.text != "false" && strikeNode.attribute(by: "w:val")?.text != "0"
//         }
//         if let dstrikeNode = runPropertyXML["w:dstrike"].element { // 双删除线 <w:dstrike/>
//             isDoubleStrikethrough = dstrikeNode.attribute(by: "w:val")?.text != "false" && dstrikeNode.attribute(by: "w:val")?.text != "0"
//             if isDoubleStrikethrough { isStrikethrough = true } // 为简化，双删除线暂时视为单删除线
//         }
//
//        // 文本颜色 <w:color w:val="RRGGBB"/>
//        if let colorVal = runPropertyXML["w:color"].attributeValue(by: "w:val"), colorVal != "auto" {
//            foregroundColor = UIColor(hex: colorVal) ?? .black // "auto" 表示使用默认颜色
//        }
//        
//        // 高亮颜色 <w:highlight w:val="..."/>
//         if let highlightVal = runPropertyXML["w:highlight"].attributeValue(by: "w:val"), highlightVal != "none" {
//             highlightColor = mapHighlightColor(highlightVal)
//         }
//
//        // 垂直对齐 (上标/下标) <w:vertAlign w:val="..."/>
//        if let vertAlign = runPropertyXML["w:vertAlign"].attributeValue(by: "w:val") {
//            switch vertAlign {
//            case "superscript": verticalAlign = 1 // 上标
//            case "subscript": verticalAlign = 2   // 下标
//            default: verticalAlign = 0           // 基线
//            }
//        }
//
//        // 构建字体 (Font)
//        var traits: UIFontDescriptor.SymbolicTraits = [] // 字体特征
//        if isBold { traits.insert(.traitBold) }
//        if isItalic { traits.insert(.traitItalic) }
//
//        var finalFont: UIFont?
//        if let baseFont = UIFont(name: fontName ?? DocxConstants.defaultFontName, size: fontSize) {
//            if let fontDescriptor = baseFont.fontDescriptor.withSymbolicTraits(traits) {
//                finalFont = UIFont(descriptor: fontDescriptor, size: fontSize) // 应用特征
//            } else {
//                finalFont = baseFont // 如果无法应用特征，使用基础字体
//            }
//        } else {
//             // 如果字体名称无效，则回退
//             print("警告: 字体 '\(fontName ?? "nil")' 未找到。回退到系统字体。")
//             let systemFont = UIFont.systemFont(ofSize: fontSize)
//             if let descriptor = systemFont.fontDescriptor.withSymbolicTraits(traits) {
//                 finalFont = UIFont(descriptor: descriptor, size: fontSize)
//             } else {
//                 finalFont = systemFont
//             }
//        }
//
//        // 应用属性
//        if let font = finalFont {
//            attributes[.font] = font
//        }
//        attributes[.foregroundColor] = foregroundColor
//        if isUnderline {
//            attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
//            // attributes[.underlineColor] = foregroundColor // 可选: 设置下划线颜色
//        }
//        if isStrikethrough {
//             attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
//             // attributes[.strikethroughColor] = foregroundColor // 可选: 设置删除线颜色
//         }
//        if let bgColor = highlightColor {
//             attributes[.backgroundColor] = bgColor // 背景高亮色
//         }
//        if verticalAlign != 0 { // 如果是上标或下标
//            // 调整基线偏移量，上标为正，下标为负。因子可按需调整。
//            attributes[.baselineOffset] = (verticalAlign == 1) ? (fontSize * 0.33) : -(fontSize * 0.25)
//            // 为获得更好的外观，略微减小上标/下标的字号
//            if let smallerFont = finalFont?.withSize(fontSize * 0.75) {
//                attributes[.font] = smallerFont
//            }
//        }
//
//        return attributes
//    }
//    
//    // MARK: - 超链接处理 (Hyperlink Processing)
//    private func processHyperlink(hyperlinkXML: XMLNode, paraProps: (paragraphAttributes: Attributes, runAttributes: Attributes)) throws -> NSAttributedString? {
//        // 获取超链接的关系ID (r:id)
//        guard let relationshipId = hyperlinkXML.attributeValue(by: "r:id"),
//              // 从已解析的关系中查找目标路径
//              let targetPath = relationships[relationshipId] else {
//            // 如果没有ID或目标，则仅将包含的运行作为普通文本处理
//             print("警告: 超链接找到，但关系中缺少有效的 r:id 或目标。作为文本处理。")
//             let runsAttributedString = NSMutableAttributedString()
//             for runNode in hyperlinkXML["w:r"].all { // 遍历超链接内的所有文本运行 <w:r>
//                  if let runString = try processRun(runXML: runNode, paraProps: paraProps) {
//                      runsAttributedString.append(runString)
//                  }
//             }
//             return runsAttributedString.length > 0 ? runsAttributedString : nil
//        }
//        
//        var linkURL: URL?
//        // 检查目标是外部URL还是内部锚点
//        if targetPath.starts(with: "http://") || targetPath.starts(with: "https://") || targetPath.starts(with: "mailto:") {
//             linkURL = URL(string: targetPath) // 创建外部URL
//        } else if let anchor = hyperlinkXML.attributeValue(by: "w:anchor") { // 内部书签链接
//             // NSAttributedString 对内部书签链接的支持不佳，除非自定义处理
//             print("检测到内部锚点链接: \(anchor)。目标: \(targetPath)。作为文本处理。")
//             // 可以创建自定义属性或使用占位符URL方案。
//        } else {
//            // 可能是指向另一个文件的相对路径 - 如果需要则处理
//             print("未处理的超链接目标: \(targetPath)。作为文本处理。")
//        }
//
//        // 处理超链接内的运行以获取显示文本和样式
//        let hyperlinkContent = NSMutableAttributedString()
//        for runNode in hyperlinkXML["w:r"].all {
//            if let runString = try processRun(runXML: runNode, paraProps: paraProps) {
//                hyperlinkContent.append(runString)
//            }
//        }
//
//        // 如果找到有效的URL，则应用链接属性
//        if let url = linkURL, hyperlinkContent.length > 0 {
//             // 如果运行样式未指定，则添加默认的蓝色和下划线
//             hyperlinkContent.enumerateAttributes(in: NSRange(0..<hyperlinkContent.length), options: []) { attrs, range, _ in
//                 // 如果未显式设置颜色，则设为蓝色
//                 if attrs[.foregroundColor] == nil {
//                      hyperlinkContent.addAttribute(.foregroundColor, value: UIColor.blue, range: range)
//                 }
//                 // 如果未显式设置下划线样式 (即使是 "none")，则添加单下划线
//                 if attrs[.underlineStyle] == nil {
//                     hyperlinkContent.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
//                 }
//             }
//             hyperlinkContent.addAttribute(.link, value: url, range: NSRange(location: 0, length: hyperlinkContent.length))
//        } else {
//            // 如果没有有效URL，则返回带样式的文本，不带链接属性
//            print("警告: 无法为超链接 r:id \(relationshipId) -> \(targetPath) 创建有效URL")
//        }
//        
//        return hyperlinkContent.length > 0 ? hyperlinkContent : nil
//    }
//
//    // MARK: - 图像处理 (Drawing/Image Processing)
//    private func processDrawing(drawingXML: XMLNode) throws -> NSAttributedString? {
//        // 在不同可能路径中查找图像数据嵌入引用
//        // 常见路径: w:drawing/wp:inline/a:graphic/a:graphicData/pic:pic/pic:blipFill/a:blip
//        //         或 w:drawing/wp:anchor/a:graphic/a:graphicData/pic:pic/pic:blipFill/a:blip
//        //         或 w:pict/v:shape/v:imagedata (VML格式)
//        
//        var embedId: String? = nil // 图像的 r:embed 或 r:id
//        var extentX: CGFloat? = nil // 宽度 (EMU)
//        var extentY: CGFloat? = nil // 高度 (EMU)
//
//        // 尝试查找 OpenXML DrawingML 格式的图像 (<a:blip>)
//        if let blip = drawingXML.deepSearch(elements: ["a:blip"]).first {
//             embedId = blip.attributeValue(by: "r:embed")
//             // 尝试在 <wp:inline> 或 <wp:anchor> 路径中找到尺寸 <wp:extent>
//             if let extent = drawingXML.deepSearch(elements: ["wp:extent"]).first {
//                 extentX = (extent.attributeValue(by: "cx") as NSString?)?.doubleValue as? CGFloat ?? 0
//                 extentY = (extent.attributeValue(by: "cy") as NSString?)?.doubleValue as? CGFloat ?? 0
//             }
//        } else if let imageData = drawingXML.deepSearch(elements: ["v:imagedata"]).first { // VML 图像格式 (较旧)
//            embedId = imageData.attributeValue(by: "r:id")
//            // VML 使用 'style' 或 width/height 属性表示尺寸 - 解析更复杂
//            print("检测到 VML 图像 (v:imagedata) - 尺寸解析未完全实现。")
//            if let style = drawingXML.deepSearch(elements: ["v:shape"]).first?.attributeValue(by: "style") {
//                // 基础解析 style="width:..pt;height:..pt"
//                if let widthStr = style.extractValue(forKey: "width", unit: "pt") { extentX = widthStr * DocxConstants.emuPerPoint }
//                if let heightStr = style.extractValue(forKey: "height", unit: "pt") { extentY = heightStr * DocxConstants.emuPerPoint }
//            }
//        }
//
//        // 必须有 embedId，以及从关系中查找到的图像相对路径，和媒体文件的基URL
//        guard let id = embedId,
//              let imageRelativePath = relationships[id], // 例如 "media/image1.png"
//              let base = mediaBaseURL else {
//            print("警告: 找到图像，但无法找到嵌入ID (\(embedId ?? "nil")) 或关系或媒体基URL。")
//            return NSAttributedString(string: "[图像: 缺少引用]")
//        }
//
//        // 构建图像文件的完整路径
//        let imageURL = base.appendingPathComponent(imageRelativePath)
//        
//        guard FileManager.default.fileExists(atPath: imageURL.path) else {
//            print("警告: 图像文件未在预期路径找到: \(imageURL.path)")
//            return NSAttributedString(string: "[图像: 文件未找到于 \(imageRelativePath)]")
//        }
//
//        if let image = UIImage(contentsOfFile: imageURL.path) {
//            let textAttachment = NSTextAttachment()
//            textAttachment.image = image
//
//            // 如果XML中有尺寸信息 (cx, cy) 且大于0，则使用这些尺寸
//            // 否则，使用图像的固有尺寸
//             if let cx = extentX, let cy = extentY, cx > 0, cy > 0 {
//                 let widthInPoints = cx / DocxConstants.emuPerPoint // EMU 转磅
//                 let heightInPoints = cy / DocxConstants.emuPerPoint // EMU 转磅
//                 textAttachment.bounds = CGRect(x: 0, y: 0, width: widthInPoints, height: heightInPoints)
//                 print("图像 \(imageRelativePath): 应用尺寸 \(widthInPoints)x\(heightInPoints) 磅")
//             } else {
//                  print("图像 \(imageRelativePath): 使用固有尺寸 \(image.size)")
//                 // 可选: 如果需要，可以限制最大宽度/高度
//                 // textAttachment.bounds = CGRect(origin: .zero, size: image.size)
//             }
//
//            return NSAttributedString(attachment: textAttachment) // 返回包含图像附件的NSAttributedString
//        } else {
//             print("警告: 从路径加载图像失败: \(imageURL.path)")
//             return NSAttributedString(string: "[图像: 加载失败于 \(imageRelativePath)]")
//        }
//    }
//    
//    // MARK: - 图表处理 (Chart Processing - 占位符)
//    private func processChart(node: XMLNode) -> String? { // 目前只是占位符
//         // 基于关系ID的简单占位符
//         if let chartId = node.attributeValue(by: "r:id") {
//             let target = relationships[chartId] ?? "未知目标"
//             print("检测到图表: r:id=\(chartId), 目标=\(target)。使用占位符。")
//             return "[图表: \(chartId)]"
//         }
//         return "[未知图表]"
//     }
//
//    // MARK: - 辅助函数 (Helper Functions)
//    
//    // 将 OOXML 标准高亮颜色名称映射到 UIColor
//    private func mapHighlightColor(_ value: String) -> UIColor? {
//         switch value.lowercased() { // 转换为小写以进行不区分大小写的比较
//             case "black": return UIColor(white: 0.2, alpha: 0.5) // 黑色高亮用半透明灰色？
//             case "blue": return UIColor.blue.withAlphaComponent(0.3)
//             case "cyan": return UIColor.cyan.withAlphaComponent(0.3)
//             case "green": return UIColor.green.withAlphaComponent(0.3)
//             case "magenta": return UIColor.magenta.withAlphaComponent(0.3)
//             case "red": return UIColor.red.withAlphaComponent(0.3)
//             case "yellow": return UIColor.yellow.withAlphaComponent(0.5) // 黄色通常更醒目
//             case "white": return UIColor(white: 0.9, alpha: 0.5) // 白色高亮用浅灰色？
//             case "darkblue": return UIColor.blue.withAlphaComponent(0.5) // 深色使用更高的alpha值
//             case "darkcyan": return UIColor.cyan.withAlphaComponent(0.5)
//             case "darkgreen": return UIColor.green.withAlphaComponent(0.5)
//             case "darkmagenta": return UIColor.magenta.withAlphaComponent(0.5)
//             case "darkred": return UIColor.red.withAlphaComponent(0.5)
//             case "darkyellow": return UIColor.yellow.withAlphaComponent(0.7)
//             case "darkgray": return UIColor.darkGray.withAlphaComponent(0.5)
//             case "lightgray": return UIColor.lightGray.withAlphaComponent(0.5)
//             case "none": return nil // 无高亮
//             default: return nil // 未知颜色
//         }
//     }
//
//    // MARK: - PDF Generation (PDF 生成)
//    /**
//     * 将 NSAttributedString 转换为 PDF 数据。
//     * - Parameter attributedString: 要转换为 PDF 的 NSAttributedString。
//     * - Parameter pageRect: PDF 页面的 CGRect，默认为 A4。
//     * - Parameter margins: PDF 页面的 UIEdgeInsets，默认为 1 英寸。
//     * - Throws: DocParserError 如果 PDF 生成失败。
//     * - Returns: 表示 PDF 文档的 Data。
//     */
//    func generatePDF(
//        from attributedString: NSAttributedString,
//        pageRect: CGRect = DocxConstants.a4PageRect,
//        margins: UIEdgeInsets = DocxConstants.defaultPDFMargins,
//        saveToURL: URL? = nil
//    ) throws -> Data {
//        // 验证输入
//        guard pageRect.width > 0, pageRect.height > 0 else {
//            throw DocParserError.pdfGenerationFailed("页面尺寸无效")
//        }
//        guard attributedString.length > 0 else {
//            throw DocParserError.pdfGenerationFailed("输入的NSAttributedString为空")
//        }
//
//        let pdfData = NSMutableData()
//        let documentInfo: [String: Any] = [
//            kCGPDFContextTitle as String: "Generated PDF",
//            kCGPDFContextAuthor as String: "YourAppName"
//        ]
//        
//        // 开始 PDF 上下文
//        UIGraphicsBeginPDFContextToData(pdfData, pageRect, documentInfo)
//        defer { UIGraphicsEndPDFContext() }
//
//        let framesetter = CTFramesetterCreateWithAttributedString(attributedString as CFAttributedString)
//        var currentLocation: CFIndex = 0
//        var currentPage: Int = 1 // 添加当前页码变量
//
//        while currentLocation < attributedString.length {
//            UIGraphicsBeginPDFPageWithInfo(pageRect, nil)
//            
//            // 计算文本绘制区域
//            let textRect = CGRect(
//                x: margins.left,
//                y: margins.top,
//                width: pageRect.width - margins.left - margins.right,
//                height: pageRect.height - margins.top - margins.bottom
//            )
//            
//            let path = CGMutablePath()
//            path.addRect(textRect)
//            
//            // 创建文本框架
//            let frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(currentLocation, 0), path, nil)
//            
//            // 获取可见字符串范围
//            guard let currentContext = UIGraphicsGetCurrentContext() else {
//                throw DocParserError.pdfGenerationFailed("无法获取当前PDF图形上下文 (第\(currentPage)页)")
//            }
//            
//            // 翻转坐标系
//            currentContext.textMatrix = .identity
//            currentContext.translateBy(x: 0, y: pageRect.height)
//            currentContext.scaleBy(x: 1.0, y: -1.0)
//            
//            // 绘制文本
//            CTFrameDraw(frame, currentContext)
//            
//            // 获取可见字符串范围
//            let visibleRange = CTFrameGetVisibleStringRange(frame)
//            // 注意：visibleRange.length 可能不准确，需要进一步处理
//            
//            // 更准确的方法是计算当前帧的实际渲染范围
//            // 这里我们假设整个帧都被渲染
//            let frameLength = attributedString.length - currentLocation
//            let safeLength = min(visibleRange.length, frameLength)
//            
//            // 更新当前位置
//            currentLocation += safeLength
//            
//            // 如果没有更多字符可渲染，退出循环
//            if safeLength == 0 {
//                break
//            }
//            
//            // 添加页码
//            currentContext.saveGState()
//            currentContext.scaleBy(x: 1.0, y: -1.0)
//            currentContext.translateBy(x: 0, y: -pageRect.height)
//            
//            let pageNumText = NSAttributedString(
//                string: "第 \(currentPage) 页",
//                attributes: [
//                    .font: UIFont.systemFont(ofSize: 10),
//                    .foregroundColor: UIColor.black
//                ]
//            )
//            
//            // 计算页码位置
//            let pageNumSize = pageNumText.size()
//            let pageNumOrigin = CGPoint(
//                x: pageRect.width - margins.right - pageNumSize.width - 10,
//                y: margins.bottom + pageNumSize.height - 10
//            )
//            
//            pageNumText.draw(at: pageNumOrigin)
//            currentContext.restoreGState()
//            
//            currentPage += 1 // 增加页码
//        }
//
//        // 验证生成的PDF数据
//        guard !pdfData.isEmpty else {
//            throw DocParserError.pdfGenerationFailed("生成的PDF数据为空")
//        }
//
//        // 保存到文件
//        if let outputURL = saveToURL {
//            do {
//                try pdfData.write(to: outputURL, options: .atomic)
//                print("PDF 已成功保存到: \(outputURL.path)")
//            } catch {
//                throw DocParserError.pdfSavingFailed(error)
//            }
//        }
//
//        print("PDF 生成完毕，共 \(currentPage - 1) 页。")
//        return pdfData as Data
//    }
//    
//    
//}
//
//// MARK: - UIColor 十六进制初始化器 (UIColor Hex Initializer)
//extension UIColor {
//    // 从十六进制字符串 (例如 "RRGGBB" 或 "#RRGGBB") 初始化颜色
//    convenience init?(hex: String) {
//        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
//        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
//
//        var rgb: UInt64 = 0
//
//        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else {
//            return nil // 扫描十六进制失败
//        }
//
//        let length = hexSanitized.count
//        let r, g, b: CGFloat
//        if length == 6 { // RRGGBB
//            r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
//            g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
//            b = CGFloat(rgb & 0x0000FF) / 255.0
//        } else {
//            // 可以添加对3位十六进制或带alpha的十六进制的支持
//            return nil // 目前仅支持 RRGGBB
//        }
//
//        self.init(red: r, green: g, blue: b, alpha: 1.0)
//    }
//}
//
//// MARK: - XMLIndexer 深度搜索辅助 (XMLIndexer Deep Search Helper)
//extension XMLIndexer {
//    // 执行广度优先搜索，查找具有匹配名称的元素
//    func deepSearch(elements names: [String]) -> [XMLIndexer] {
//        var results: [XMLIndexer] = []
//        var queue: [XMLIndexer] = [self] // 初始化队列，包含当前节点
//
//        while !queue.isEmpty {
//            let current = queue.removeFirst() // 取出队首元素
//            // 如果当前元素的名称在要查找的名称列表中，则添加到结果
//            if let elementName = current.element?.name, names.contains(elementName) {
//                results.append(current)
//            }
//            // 将当前元素的所有子元素添加到队列中以进行进一步搜索
//            queue.append(contentsOf: current.children)
//        }
//        return results
//    }
//}
//
//
//// MARK: - String 扩展，用于 VML 样式解析 (基础) (String Extension for VML Style Parsing (Basic))
//extension String {
//    // 从形如 "key: value unit; key2: value2 unit2" 的样式字符串中提取特定键的值
//    // 例如: extractValue(forKey: "width", unit: "pt") 从 "width:100pt;height:50pt" 提取 100.0
//    func extractValue(forKey key: String, unit: String) -> CGFloat? {
//        // 正则表达式匹配 "key: 数字.可选数字单位"
//        let pattern = "\(key):\\s*([0-9.]+)\\s*\(unit)"
//        // 使用不区分大小写的正则匹配
//        if let range = self.range(of: pattern, options: [.regularExpression, .caseInsensitive]),
//           // 获取捕获组 (即括号内的数字部分)
//           let valueString = self.substring(with: range).matches(for: pattern).first?.last,
//           let value = Double(valueString) {
//            return CGFloat(value)
//        }
//        return nil
//    }
//
//    // 辅助函数：获取正则表达式匹配的捕获组
//    func matches(for regex: String) -> [[String]] {
//        do {
//            let regex = try NSRegularExpression(pattern: regex)
//            let results = regex.matches(in: self, range: NSRange(self.startIndex..., in: self))
//            return results.map { result in
//                return (0..<result.numberOfRanges).map {
//                    // 如果捕获组存在，则提取字符串，否则为空字符串
//                    result.range(at: $0).location != NSNotFound
//                        ? String(self[Range(result.range(at: $0), in: self)!])
//                        : ""
//                }
//            }
//        } catch {
//            print("无效的正则表达式: \(error.localizedDescription)")
//            return []
//        }
//    }
//
//     // 辅助函数：从 NSRange 获取子字符串
//     func substring(with nsrange: NSRange) -> String? {
//         guard let range = Range(nsrange, in: self) else { return nil }
//         return String(self[range])
//     }
//}
// ************************************完整可解析出来的代码1*************************


import Foundation
import Zip // Pod: 'Zip', '~> 2.1'
import SWXMLHash // Pod: 'SWXMLHash', '~> 7.0'
import UIKit // For NSAttributedString, UIFont, UIColor, UIImage, NSTextAttachment

// MARK: - 错误处理 (Error Handling)
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

// MARK: - 常量和辅助结构 (Constants and Helpers)
struct DocxConstants {
    // OOXML 单位: English Metric Unit (EMU)
    static let emuPerPoint: CGFloat = 12700.0     // 1 磅 (point) = 12700 EMU
    // 默认字体设置
    static let defaultFontSize: CGFloat = 12.0    // 默认字体大小（磅）
    static let defaultFontName: String = "Times New Roman" // 常见的默认字体 (如果文档中未指定)

    // PDF 生成常量 (用于自定义的 saveDocToPDF/generatePDFWithCustomLayout 方法)
    static let defaultPDFPageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // 默认PDF页面尺寸 (US Letter: 8.5x11 inches)
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

// MARK: - DocParser 类 (DocParser Class)
class DocParser {
    typealias XMLNode = XMLIndexer         // XML节点的类型别名
    typealias Attributes = [NSAttributedString.Key: Any] // NSAttributedString属性字典的类型别名

    private var relationships: [String: String] = [:] // 存储关系ID到目标路径的映射 (例如 rId1 -> media/image1.png)
    private var mediaBaseURL: URL?                    // 解压后 'word' 目录的URL，用于构建媒体文件的完整路径

    // MARK: - 公共接口 (Public Interface)
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
            print("DOCX解压到: \(unzipDirectory.path)")
        } catch {
            print("解压DOCX文件错误: \(error)")
            throw DocParserError.unzipFailed(error)
        }

        // 设置媒体文件的基础URL (通常是 word/media/ 目录，但关系路径会包含 "media/")
        self.mediaBaseURL = unzipDirectory.appendingPathComponent("word", isDirectory: true)

        // 2. 解析关系文件 (word/_rels/document.xml.rels)
        // 这个文件定义了主文档中引用的外部资源（如图片、超链接）的ID和实际路径。
        let relsURL = unzipDirectory.appendingPathComponent("word/_rels/document.xml.rels")
        if FileManager.default.fileExists(atPath: relsURL.path) {
            try parseRelationships(relsFileURL: relsURL)
            print("已解析 \(relationships.count) 个关系。")
        } else {
            print("警告: 关系文件 'word/_rels/document.xml.rels' 未找到。")
            // 没有关系文件也可以继续，但图片、超链接等依赖关系的功能将无法正常工作。
        }

        // 3. 解析主文档 (word/document.xml)
        // 这是包含实际文本内容和结构的核心XML文件。
        let mainDocumentURL = unzipDirectory.appendingPathComponent("word/document.xml")
        guard FileManager.default.fileExists(atPath: mainDocumentURL.path) else {
            throw DocParserError.fileNotFound("word/document.xml")
        }
        print("正在解析主文档: \(mainDocumentURL.path)")

        let xmlString: String
        let xml: XMLNode // XML 解析后的根节点
        do {
            xmlString = try String(contentsOf: mainDocumentURL, encoding: .utf8)
            xml = XMLHash.parse(xmlString) // 使用 SWXMLHash Pod 解析 XML
        } catch {
            print("读取或解析主文档XML错误: \(error)")
            throw DocParserError.xmlParsingFailed(error)
        }
        
        // 4. 将 XML 结构处理为 NSAttributedString
        // 从 <w:body> 元素开始处理
        let attributedString = try processBody(xml: xml["w:document"]["w:body"])
        
        // 5. 清理临时解压目录 (可选, 根据具体应用的生命周期管理决定是否立即清理)
        // try? FileManager.default.removeItem(at: unzipDirectory)
        // print("已清理临时目录: \(unzipDirectory.path)")
        
        return attributedString
    }

    // MARK: - 关系解析 (Relationship Parsing)
    private func parseRelationships(relsFileURL: URL) throws {
        relationships = [:] // 重置/初始化关系字典
        do {
            let xmlString = try String(contentsOf: relsFileURL, encoding: .utf8)
            let xml = XMLHash.parse(xmlString)
            // 遍历 <Relationships> 下的每一个 <Relationship> 元素
            for element in xml["Relationships"]["Relationship"].all {
                if let id = element.attributeValue(by: "Id"),       // 获取 Id 属性 (例如 "rId1")
                   let target = element.attributeValue(by: "Target") { // 获取 Target 属性 (例如 "media/image1.png" 或 "http://example.com")
                    relationships[id] = target // 存储 ID 和 Target 的映射
                }
            }
        } catch {
            print("解析关系文件错误: \(error)")
            throw DocParserError.relationshipParsingFailed(error.localizedDescription)
        }
    }

    // MARK: - 主体内容处理 (Main Body Processing)
    // 处理 <w:body> 元素及其子元素 (如段落 <w:p>, 表格 <w:tbl>)
    private func processBody(xml: XMLNode) throws -> NSAttributedString {
        let finalAttributedString = NSMutableAttributedString()

        // 遍历 w:body 下的所有直接子元素
        for element in xml.children {
            if element.element?.name == "w:p" { // 段落 (Paragraph)
                // print("处理段落...")
                let paragraphString = try processParagraph(paragraphXML: element)
                finalAttributedString.append(paragraphString)
                // 在每个DOCX段落后追加一个换行符，以在NSAttributedString中保持段落分隔。
                // 这是因为DOCX的<w:p>本身就代表一个块级结构。
                // 如果段落内容本身以换行符结尾（例如段内有<w:br/>），这个额外的\n可能会导致双换行。
                // 需要在PDF渲染时或processParagraph内部更细致地处理末尾换行。
                finalAttributedString.append(NSAttributedString(string: "\n"))
            } else if element.element?.name == "w:tbl" { // 表格 (Table)
                 // print("处理表格...")
                 let tableString = try processTable(tableXML: element) // 表格内容被转换为带制表符和换行符的文本
                 finalAttributedString.append(tableString)
                 finalAttributedString.append(NSAttributedString(string: "\n")) // 表格结束后也添加换行符
             } else if element.element?.name == "w:sectPr" { // 章节属性 (Section Properties)
                 // 包含页面设置、分栏等信息，目前解析器忽略这些。
                 // print("跳过章节属性 (w:sectPr)")
             } else if element.element?.name == "w:sdt" { // 结构化文档标签 (Structured Document Tag / Content Control)
                 // print("处理结构化文档标签 (w:sdt)...")
                 let sdtContent = element["w:sdtContent"] // 获取其内容部分
                 let contentString = try processBody(xml: sdtContent) // 递归处理SDT的内容 (可能包含段落、表格等)
                 finalAttributedString.append(contentString)
             } else {
                 // print("跳过未知的主体元素: \(element.element?.name ?? "nil")")
             }
        }

        // 清理：如果最终的富文本以换行符结尾，移除它，避免文档末尾有空行。
        if finalAttributedString.length > 0 && finalAttributedString.string.hasSuffix("\n") {
            finalAttributedString.deleteCharacters(in: NSRange(location: finalAttributedString.length - 1, length: 1))
        }
        
        return finalAttributedString
    }
    
    // MARK: - 表格处理 (Table Processing - 结构化)
    // 将表格XML解析为 TableDrawingData 对象，并将其附加到特殊的NSAttributedString上
    private func processTable(tableXML: XMLNode) throws -> NSAttributedString {
        var columnWidthsTwips: [CGFloat] = []      // 列宽 (单位: Twips)。Twip (Twentieth of a Point) 是Word中常用的长度单位，1 Point = 20 Twips。
        var defaultTableBorders = TableBorders()   // 表格的默认边框设置，从 <w:tblPr><w:tblBorders> 解析。
        var tableIndentationTwips: CGFloat = 0     // 表格整体的左侧缩进 (单位: Twips)，从 <w:tblInd> 解析。

        // 1. 解析表格网格定义 (<w:tblGrid>) 以获取各列的建议宽度。
        //    <w:tblGrid> 包含一系列 <w:gridCol w:w="widthInTwips"/> 元素。
        if let tblGridElement = tableXML["w:tblGrid"].element { // 获取 <w:tblGrid> 对应的 XMLElement
            for childContent in tblGridElement.children { // 遍历 <w:tblGrid> 的所有子节点
                if let gridColElement = childContent as? XMLElement, gridColElement.name == "w:gridCol" { // 确保子节点是 <w:gridCol> 元素
                    let gridColIndexer = XMLIndexer(gridColElement) // 将 XMLElement 包装成 XMLIndexer 以方便访问属性
                    if let wStr = gridColIndexer.attributeValue(by: "w:w"), let w = Double(wStr) { // 获取 w:w 属性值 (宽度，Twips)
                        columnWidthsTwips.append(CGFloat(w))
                    } else {
                        // 如果 <w:gridCol> 没有指定宽度，则使用一个默认值。
                        // Word 通常会确保指定，但作为健壮性处理。
                        columnWidthsTwips.append(2160) // 2160 Twips 约等于 1.5英寸 或 108磅，一个常见的默认列宽。
                    }
                }
            }
        }

        // 如果文档中没有提供 <w:tblGrid> (这对于有效的OOXML来说很少见)，
        // 则尝试根据第一行实际的单元格数量和它们的列合并情况来估算列数和平均列宽。
        if columnWidthsTwips.isEmpty {
            if let firstRowIndexer = tableXML["w:tr"].all.first, // 安全地获取第一个 <w:tr> 的 XMLIndexer
               let firstRowElement = firstRowIndexer.element { // 获取 <w:tr> 的 XMLElement
                
                // 获取第一行中所有的 <w:tc> (单元格) 元素
                let cellElements = firstRowElement.children.compactMap { $0 as? XMLElement }.filter { $0.name == "w:tc" }

                if !cellElements.isEmpty {
                    // 计算第一行的总逻辑列数，考虑每个单元格的 <w:gridSpan> (列合并)
                    let estimatedColumnCount = cellElements.reduce(0) { count, cellElement in
                        let cellIndexer = XMLIndexer(cellElement) // 包装 XMLElement
                        let spanStr = cellIndexer["w:tcPr"]["w:gridSpan"].attributeValue(by: "w:val") // 获取列合并值
                        return count + (Int(spanStr ?? "1") ?? 1) // 如果没有指定或无效，则默认为1
                    }
                    
                    if estimatedColumnCount > 0 {
                        // 将页面宽度的90%均分给估算出的列数
                        let avgWidthTwips = (DocxConstants.defaultPDFPageRect.width * 0.9 * 20.0) / CGFloat(estimatedColumnCount) // 页面宽度(磅) * 0.9 * 20 (磅转Twips) / 列数
                        columnWidthsTwips = Array(repeating: avgWidthTwips, count: estimatedColumnCount)
                        print("警告: 表格缺少 <w:tblGrid>。正在根据第一行估算 \(estimatedColumnCount) 列宽度。")
                    } else {
                         // 如果估算的列数为0 (不太可能，但作为防御)，则按单列处理
                         columnWidthsTwips = [DocxConstants.defaultPDFPageRect.width * 0.9 * 20.0]
                         print("警告: 表格第一行无法确定列数。使用单宽列。")
                    }
                } else {
                    // 如果第一行没有单元格，也按单列处理
                    columnWidthsTwips = [DocxConstants.defaultPDFPageRect.width * 0.9 * 20.0]
                    print("警告: 表格第一行无单元格或无法解析列数。使用单宽列。")
                }
            } else {
                // 如果表格连行都没有，或无法解析第一行，则按单列处理
                columnWidthsTwips = [DocxConstants.defaultPDFPageRect.width * 0.9 * 20.0]
                print("警告: 表格无行或无法解析列数。使用单宽列。")
            }
        }
        // 将所有列宽从 Twips 单位转换为 Points 单位，因为PDF绘制通常使用Points。
        let columnWidthsPoints = columnWidthsTwips.map { $0 / 20.0 }

        // 2. 解析表格级别的属性 (<w:tblPr>)
        let tblPrIndexer = tableXML["w:tblPr"] // 获取 <w:tblPr> 的 XMLIndexer
        if tblPrIndexer.element != nil { // 检查 <w:tblPr> 是否存在
            // 解析表格的默认边框设置 (<w:tblBorders>)
            let tblBordersIndexer = tblPrIndexer["w:tblBorders"] // 获取 <w:tblBorders> 的 XMLIndexer
            if tblBordersIndexer.element != nil {
                // 调用辅助函数 parseBorderElement 分别解析上、下、左、右、内部水平、内部垂直边框
                defaultTableBorders.top = parseBorderElement(tblBordersIndexer["w:top"])
                defaultTableBorders.left = parseBorderElement(tblBordersIndexer["w:left"])
                defaultTableBorders.bottom = parseBorderElement(tblBordersIndexer["w:bottom"])
                defaultTableBorders.right = parseBorderElement(tblBordersIndexer["w:right"])
                defaultTableBorders.insideHorizontal = parseBorderElement(tblBordersIndexer["w:insideH"])
                defaultTableBorders.insideVertical = parseBorderElement(tblBordersIndexer["w:insideV"])
            }
            // 解析表格的左侧缩进 (<w:tblInd w:w="widthInTwips" w:type="dxa">)
            let tblIndIndexer = tblPrIndexer["w:tblInd"] // 获取 <w:tblInd> 的 XMLIndexer
            if tblIndIndexer.element != nil, // 检查是否存在
               let wStr = tblIndIndexer.attributeValue(by: "w:w"), let w = Double(wStr), // 获取宽度值
               (tblIndIndexer.attributeValue(by: "w:type") == "dxa" || tblIndIndexer.attributeValue(by: "w:type") == nil /* dxa是默认类型 */ ) { // 检查类型是否为dxa (Twips)
                tableIndentationTwips = CGFloat(w)
            }
            // TODO: 未来可以解析 <w:tblLook> 用于条件格式化 (如首行、末行、奇偶行/列的特殊样式) - 这部分逻辑较复杂。
            // TODO: 未来可以解析 <w:tblStyle> 以应用来自 styles.xml 文件中定义的表格样式 - 这部分逻辑也较复杂。
        }

        var tableRowsData: [TableRowDrawingData] = [] // 用于存储解析出的每一行的数据
        // 用于跟踪垂直合并 (vMerge) 的状态。键是逻辑列的索引，值是开始合并的那个单元格的数据。
        var vMergeTracker: [Int: TableCellDrawingData] = [:]

        // 3. 遍历并处理表格中的每一行 (<w:tr>)
        for (rowIndex, rowXML) in tableXML["w:tr"].all.enumerated() { // rowXML 是当前行的 XMLIndexer
            var cellsDataInCurrentRow: [TableCellDrawingData] = [] // 存储当前行解析出的所有单元格数据
            var currentLogicalColumnIndex = 0 // 当前正在处理的逻辑列的起始索引 (考虑了前面单元格的列合并)

            let trPrIndexer = rowXML["w:trPr"] // 获取当前行属性 <w:trPr> 的 XMLIndexer
            var rowSpecifiedHeightPoints: CGFloat? = nil // 当前行指定的行高 (Points)
            var isHeaderRow = false // 标记当前行是否为表头行

            if trPrIndexer.element != nil { // 检查行属性是否存在
                // 解析行高 (<w:trHeight w:val="heightInTwips" w:hRule="exact|atLeast|auto">)
                let trHeightIndexer = trPrIndexer["w:trHeight"]
                if trHeightIndexer.element != nil,
                   let hStr = trHeightIndexer.attributeValue(by: "w:val"), let hValTwips = Double(hStr) {
                    // w:hRule 属性 (exact, atLeast, auto) 决定了此高度是固定值、最小值还是自动计算。
                    // 此处暂时简化，直接使用其值。
                    rowSpecifiedHeightPoints = CGFloat(hValTwips) / 20.0 // Twips 转 Points
                }
                // 检查是否为表头行 (<w:tblHeader /> 标签存在即表示是)
                if trPrIndexer["w:tblHeader"].element != nil {
                    isHeaderRow = true
                }
                // TODO: 未来可以处理 <w:cantSplit/> (行不可跨页) 等其他行属性。
            }

            // 遍历并处理当前行中的每一个单元格 (<w:tc>)
            for (cellXmlIndexInRow, cellXML) in rowXML["w:tc"].all.enumerated() { // cellXML 是当前单元格的 XMLIndexer
                let cellContentAccumulator = NSMutableAttributedString() // 用于累积单元格内的所有内容
                var cellBackgroundColor: UIColor? // 单元格背景色
                var cellGridSpan = 1              // 单元格的列合并数量，默认为1 (不合并)
                var cellVMergeStatus: VerticalMergeStatus = .none // 单元格的垂直合并状态，默认为无
                var cellSpecificBorders = defaultTableBorders   // 单元格的边框，初始继承表格默认边框，可能被单元格自身定义覆盖
                var cellMarginsPoints = UIEdgeInsets.zero     // 单元格的内边距 (Points)

                // 解析单元格属性 (<w:tcPr>)
                let tcPrIndexer = cellXML["w:tcPr"] // 获取当前单元格属性 <w:tcPr> 的 XMLIndexer
                if tcPrIndexer.element != nil { // 检查单元格属性是否存在
                    // 解析列合并 (<w:gridSpan w:val="numberOfColumnsToSpan">)
                    if let gridSpanStr = tcPrIndexer["w:gridSpan"].attributeValue(by: "w:val"), let span = Int(gridSpanStr) {
                        cellGridSpan = span
                    }

                    // 解析垂直合并 (<w:vMerge w:val="restart" /> 表示开始合并, <w:vMerge /> 表示继续合并)
                    let vMergeIndexer = tcPrIndexer["w:vMerge"]
                    if vMergeIndexer.element != nil {
                        cellVMergeStatus = (vMergeIndexer.attributeValue(by: "w:val") == "restart") ? .restart : .continue
                    } else {
                        // 如果当前单元格没有 <w:vMerge> 标签，但 vMergeTracker 中记录了当前逻辑列正在合并，
                        // 说明上一个单元格的垂直合并在此处结束。
                        if vMergeTracker[currentLogicalColumnIndex] != nil {
                             vMergeTracker.removeValue(forKey: currentLogicalColumnIndex) // 清除跟踪状态
                        }
                    }

                    // 解析单元格底纹/背景色 (<w:shd w:val="clear" w:color="auto" w:fill="RRGGBBHexColor">)
                    let shdIndexer = tcPrIndexer["w:shd"]
                    if shdIndexer.element != nil,
                       let fillHex = shdIndexer.attributeValue(by: "w:fill"), // 获取填充颜色
                       fillHex.lowercased() != "auto", // "auto" 通常表示透明或继承
                       let color = UIColor(hex: fillHex) { // 将十六进制颜色转换为 UIColor
                        cellBackgroundColor = color
                    }

                    // 解析单元格特有的边框设置 (<w:tcBorders>)，这会覆盖从表格继承的默认边框
                    let tcBordersIndexer = tcPrIndexer["w:tcBorders"]
                    if tcBordersIndexer.element != nil {
                        if tcBordersIndexer["w:top"].element != nil { cellSpecificBorders.top = parseBorderElement(tcBordersIndexer["w:top"]) }
                        if tcBordersIndexer["w:left"].element != nil { cellSpecificBorders.left = parseBorderElement(tcBordersIndexer["w:left"]) }
                        if tcBordersIndexer["w:bottom"].element != nil { cellSpecificBorders.bottom = parseBorderElement(tcBordersIndexer["w:bottom"]) }
                        if tcBordersIndexer["w:right"].element != nil { cellSpecificBorders.right = parseBorderElement(tcBordersIndexer["w:right"]) }
                        // 注意: OOXML还支持斜线边框 <w:tl2br/>, <w:tr2bl/>，此处未处理。
                    }
                    
                    // 解析单元格内边距 (<w:tcMar>)，其子元素 <w:top>, <w:left> 等定义了各方向边距，单位是Twips。
                    let tcMarIndexer = tcPrIndexer["w:tcMar"]
                    if tcMarIndexer.element != nil {
                        let twipsPerPoint: CGFloat = 20.0
                        if let wStr = tcMarIndexer["w:top"].attributeValue(by: "w:w"), let w = Double(wStr) { cellMarginsPoints.top = CGFloat(w) / twipsPerPoint }
                        if let wStr = tcMarIndexer["w:left"].attributeValue(by: "w:w"), let w = Double(wStr) { cellMarginsPoints.left = CGFloat(w) / twipsPerPoint }
                        if let wStr = tcMarIndexer["w:bottom"].attributeValue(by: "w:w"), let w = Double(wStr) { cellMarginsPoints.bottom = CGFloat(w) / twipsPerPoint }
                        if let wStr = tcMarIndexer["w:right"].attributeValue(by: "w:w"), let w = Double(wStr) { cellMarginsPoints.right = CGFloat(w) / twipsPerPoint }
                    }
                    // TODO: 未来可以解析单元格内容的垂直对齐方式 (<w:vAlign w:val="top|center|bottom">)。
                }

                // 解析单元格内的实际内容 (通常是段落 <w:p>，也可能是嵌套的表格 <w:tbl>)
                if let tcElement = cellXML.element { // 获取 <w:tc> 的 XMLElement
                    for contentNode in tcElement.children { // 遍历 <w:tc> 的所有子节点 (包括 <w:p>, <w:tbl>, 以及 <w:tcPr>等)
                        if let contentElement = contentNode as? XMLElement { // 确保子节点是 XMLElement
                            let contentIndexer = XMLIndexer(contentElement) // 包装成 XMLIndexer
                            if contentElement.name == "w:p" { // 如果是段落
                                 let paraString = try processParagraph(paragraphXML: contentIndexer) // 调用段落处理函数
                                 cellContentAccumulator.append(paraString)
                                 // 在单元格内，段落之间通常需要换行符分隔。
                                 // 如果段落本身不以换行结束，且累积器中已有内容，则添加一个。
                                 if !paraString.string.hasSuffix("\n") && cellContentAccumulator.length > 0 {
                                     cellContentAccumulator.append(NSAttributedString(string: "\n"))
                                 }
                             } else if contentElement.name == "w:tbl" { // 如果是嵌套表格
                                 let nestedTableAttrString = try processTable(tableXML: contentIndexer) // 递归调用表格处理函数
                                 cellContentAccumulator.append(nestedTableAttrString)
                                 // 嵌套表格后也需要一个换行符，因为它也是一个块级元素。
                                 if !nestedTableAttrString.string.hasSuffix("\n") && cellContentAccumulator.length > 0 {
                                     cellContentAccumulator.append(NSAttributedString(string: "\n"))
                                 }
                             }
                             // <w:tcPr> (单元格属性) 节点作为 <w:tc> 的子节点存在，但它不是可视内容，已在前面处理过，此处忽略。
                        }
                    }
                }
                // 清理：如果单元格内容末尾因最后一个段落处理逻辑而多出一个换行符，则移除它。
                if cellContentAccumulator.length > 0 && cellContentAccumulator.string.hasSuffix("\n") {
                    cellContentAccumulator.deleteCharacters(in: NSRange(location: cellContentAccumulator.length - 1, length: 1))
                }

                // 创建当前单元格的数据对象
                let currentCellData = TableCellDrawingData(
                    content: cellContentAccumulator,        // 单元格内容
                    borders: cellSpecificBorders,           // 单元格边框
                    backgroundColor: cellBackgroundColor,   // 单元格背景色
                    gridSpan: cellGridSpan,                 // 列合并数
                    vMerge: cellVMergeStatus,               // 垂直合并状态
                    margins: cellMarginsPoints,             // 内边距
                    originalRowIndex: rowIndex,             // 原始行索引
                    originalColIndex: currentLogicalColumnIndex // 原始逻辑列索引
                )
                cellsDataInCurrentRow.append(currentCellData) // 添加到当前行的数据列表中

                // 更新垂直合并的跟踪状态
                if cellVMergeStatus == .restart { // 如果此单元格是垂直合并的起始点
                    // 记录这个起始单元格，它可能会跨越多列 (gridSpan)
                    for i in 0..<cellGridSpan {
                        vMergeTracker[currentLogicalColumnIndex + i] = currentCellData
                    }
                }
                // 如果是 .continue，则不需要更新 tracker，因为它依赖于上面行的 .restart 单元格。
                
                currentLogicalColumnIndex += cellGridSpan // 将逻辑列索引前进当前单元格所占的列数
            }
            // 创建当前行的数据对象
            tableRowsData.append(TableRowDrawingData(cells: cellsDataInCurrentRow,
                                                     height: 0, // 实际行高将在PDF生成时根据内容计算
                                                     specifiedHeight: rowSpecifiedHeightPoints, // 存储解析到的指定行高
                                                     isHeaderRow: isHeaderRow)) // 标记是否为表头行
        }

        // 所有行和单元格处理完毕，创建最终的表格数据对象
        let finalTableDrawingData = TableDrawingData(
            rows: tableRowsData,                        // 所有行数据
            columnWidthsPoints: columnWidthsPoints,     // 所有列的宽度 (Points)
            defaultCellBorders: defaultTableBorders,    // 表格的默认边框
            tableIndentation: tableIndentationTwips / 20.0 // 表格的左缩进 (Points)
        )

        // 创建一个特殊的 NSAttributedString，它只包含一个“对象替换字符”。
        let finalAttributedString = NSMutableAttributedString(string: "\u{FFFC}") // U+FFFC OBJECT REPLACEMENT CHARACTER
        
        // 将我们精心解析和构建的 finalTableDrawingData 对象作为自定义属性，
        // 附加到这个“对象替换字符”上。
        // 这样，在后续的PDF生成阶段，当遇到这个字符时，我们就可以提取出表格数据并进行自定义绘制。
        finalAttributedString.addAttribute(DocParser.tableDrawingDataAttributeKey,
                                         value: finalTableDrawingData,
                                         range: NSRange(location: 0, length: finalAttributedString.length)) // 范围是这个特殊字符本身
        
        // 注意：返回的这个 NSAttributedString 代表整个表格对象。
        // 调用它的 processBody 函数通常会在这个表格对象之后添加一个换行符，
        // 因为表格在文档流中表现为一个块级元素。所以这里不需要再画蛇添足地加 "\n"。
        return finalAttributedString
    }

    // 辅助函数：解析 <w:bdr> (border) XML 元素节点
    private func parseBorderElement(_ borderXMLIndexer: XMLIndexer?) -> TableBorderInfo {
        guard let node = borderXMLIndexer?.element else {
            return .noBorder // 如果节点不存在，则无边框
        }

        // 如果存在 <w:bdr> 标签但其 "val" 属性为 "nil" 或 "none"，则表示无边框
        let valAttr = node.attribute(by: "w:val")?.text.lowercased()
        if valAttr == "nil" || valAttr == "none" {
            return .noBorder
        }

        var borderInfo = TableBorderInfo.defaultBorder // 如果标签存在且val不是nil/none，则默认是单实线

        // 解析边框样式 (w:val)
        if let styleVal = valAttr {
            switch styleVal {
            case "single": borderInfo.style = .single
            case "double": borderInfo.style = .double // 绘制时需要特殊处理
            case "dashed": borderInfo.style = .dashed // 绘制时需要特殊处理
            case "dotted": borderInfo.style = .dotted // 绘制时需要特殊处理
            // TODO: 添加更多 OOXML 边框样式的处理，如 "thick", "wave", "inset", "outset" 等
            default: borderInfo.style = .single // 未知样式也暂时视为单实线
            }
        } else {
            // 如果 <w:top/> 这样的标签存在，但没有 w:val 属性，通常意味着默认的单实线边框
            borderInfo.style = .single
        }

        // 解析边框宽度 (w:sz，单位是八分之一磅 1/8 pt)
        if let szStr = node.attribute(by: "w:sz")?.text, let szEighthsOfPoint = Double(szStr) {
            borderInfo.width = CGFloat(szEighthsOfPoint) / 8.0
        } else {
            // 如果未指定宽度，根据样式给一个默认值 (Word 经常对标准线条省略sz)
            if borderInfo.style == .single { borderInfo.width = 0.5 } // 0.5pt 是常见的细实线
            else if borderInfo.style == .double { borderInfo.width = 1.5 } // 双线通常整体稍宽
            // 其他样式可能也需要默认宽度
        }

        // 解析边框颜色 (w:color，值为 "RRGGBB" 或 "auto")
        if let colorHex = node.attribute(by: "w:color")?.text, colorHex.lowercased() != "auto" {
            if let color = UIColor(hex: colorHex) {
                borderInfo.color = color
            } else {
                borderInfo.color = .black // 无效的十六进制颜色值，回退到黑色
            }
        } else {
            borderInfo.color = .black // "auto" 或未指定颜色，表示黑色
        }

        // 解析边框与内容的间距 (w:space，单位是磅 pt)
        if let spaceStr = node.attribute(by: "w:space")?.text, let spacePoints = Double(spaceStr) {
            borderInfo.space = CGFloat(spacePoints)
        }
        
        // 如果最终计算出的宽度小于等于0，则视为无效边框（不绘制）
        if borderInfo.width <= 0 {
            return .noBorder
        }

        return borderInfo
    }
    
    
    // MARK: - 段落处理 (Paragraph Processing)
    // 处理单个 <w:p> 元素，提取其文本运行、样式和内嵌对象。
    private func processParagraph(paragraphXML: XMLNode) throws -> NSAttributedString {
        let paragraphAttributedString = NSMutableAttributedString()
        // 1. 解析段落属性 (<w:pPr>)，如对齐、缩进、间距、列表项等。
        //    返回两个属性集：应用于整个段落的属性，和该段落内文本运行的默认属性。
        let paragraphProperties = parseParagraphProperties(paraPropertyXML: paragraphXML["w:pPr"])

        // 2. 处理列表项前缀 (如果存在 <w:numPr> 标签)
        var listItemPrefix = ""
        let numPrIndexer = paragraphXML["w:pPr"]["w:numPr"] // 数字编号属性 <w:numPr>
        if numPrIndexer.element != nil {
            let level = numPrIndexer["w:ilvl"].attributeValue(by: "w:val").flatMap { Int($0) } ?? 0 // 列表级别 <w:ilvl w:val="0">
            // TODO: 完整的列表格式化需要解析 numbering.xml 文件来获取实际的编号格式 (如 "1.", "a)", "•")。
            // 目前使用简化的占位符表示列表项。
            let indent = String(repeating: "    ", count: level) // 每级缩进4个空格 (示例)
            let numberPlaceholder = "•" // 使用项目符号作为通用占位符 (应从numbering.xml获取)
            listItemPrefix = indent + numberPlaceholder + " "
        }
        // 如果有列表前缀，将其添加到段落开头
        if !listItemPrefix.isEmpty {
            // 使用段落的默认运行属性或一个非常基础的样式来渲染列表前缀
            var prefixAttrs = paragraphProperties.runAttributes
            if prefixAttrs[.font] == nil { // 确保字体属性存在
                prefixAttrs[.font] = UIFont(name: DocxConstants.defaultFontName, size: DocxConstants.defaultFontSize)
            }
            paragraphAttributedString.append(NSAttributedString(string: listItemPrefix, attributes: prefixAttrs))
        }

        // 3. 遍历段落内的子元素（文本运行 <w:r>、超链接 <w:hyperlink>、图片等）
        for node in paragraphXML.children {
            var appendedString: NSAttributedString? = nil // 用于收集当前子元素处理后的富文本

            if node.element?.name == "w:r" { // 文本运行 (Run)
                appendedString = try processRun(runXML: node, paraProps: paragraphProperties)
            } else if node.element?.name == "w:hyperlink" { // 超链接
                appendedString = try processHyperlink(hyperlinkXML: node, paraProps: paragraphProperties)
            } else if node.element?.name == "w:drawing" || node.element?.name == "w:pict" { // 图像 (DrawingML 或 VML)
                appendedString = try processDrawing(drawingXML: node)
            } else if node.element?.name == "w:sym" { // 符号 (Symbol), 例如 Wingdings 字体中的特殊字符
                 if let charHex = node.attributeValue(by: "w:char"), // 符号的十六进制字符代码 <w:char w:val="F0A7">
                    let fontName = node.attributeValue(by: "w:font") { // 符号使用的字体 <w:font w:val="Wingdings">
                     var symAttrs = paragraphProperties.runAttributes // 使用段落默认运行属性
                     // 尝试使用符号指定的字体
                     if let symFont = UIFont(name: fontName, size: (symAttrs[.font] as? UIFont)?.pointSize ?? DocxConstants.defaultFontSize) {
                         symAttrs[.font] = symFont
                     }
                     // 将十六进制字符代码转换为实际字符
                     let charCode: UInt32 = UInt32(charHex, radix: 16) ?? 0x25A1 // 默认使用 □
                     guard let unicodeScalar = UnicodeScalar(charCode) else {
                         fatalError("Invalid Unicode scalar for charCode: \(charCode)") // 或者处理错误
                     }
                     let actualChar = Character(unicodeScalar)
                     
                     
                     appendedString = NSAttributedString(string: String(actualChar), attributes: symAttrs)
                 }
            } else if node.element?.name == "w:tab" { // 显式制表符 <w:tab/>
                 appendedString = NSAttributedString(string: "\t", attributes: paragraphProperties.runAttributes)
            } else if node.element?.name == "w:br" { // 段内换行符 <w:br/>
                 // TODO: 可以检查 <w:br w:type="page"/> 实现分页符处理
                 appendedString = NSAttributedString(string: "\n", attributes: paragraphProperties.runAttributes)
             } else if node.element?.name == "w:smartTag" || node.element?.name == "w:proofErr" { // 智能标签或校对错误标记 (通常包含实际文本)
                 // 遍历这些标签内的子元素 (通常是 <w:r>)
                 let tempString = NSMutableAttributedString()
                 for child in node.children {
                     if child.element?.name == "w:r" {
                         if let runStr = try processRun(runXML: child, paraProps: paragraphProperties) {
                             tempString.append(runStr)
                         }
                     }
                 }
                 if tempString.length > 0 { appendedString = tempString }
             }
            // <w:pPr> 是段落属性标签，在开头已处理，此处应忽略。
            // else if node.element?.name != "w:pPr" {
            //     print("跳过未知的段落子元素: \(node.element?.name ?? "nil")")
            // }
            
            // 如果成功处理了子元素，则追加到段落富文本中
            if let str = appendedString {
                paragraphAttributedString.append(str)
            }
        }

        // 4. 将解析出的段落级属性 (对齐、间距、缩进等) 应用于整个段落的富文本。
        if paragraphAttributedString.length > 0 {
            paragraphAttributedString.addAttributes(paragraphProperties.paragraphAttributes, range: NSRange(location: 0, length: paragraphAttributedString.length))
        }

        return paragraphAttributedString
    }

    // MARK: - 段落属性解析 (Paragraph Property Parsing)
    // 解析 <w:pPr> (段落属性) 元素
    private func parseParagraphProperties(paraPropertyXML: XMLNode) -> (paragraphAttributes: Attributes, runAttributes: Attributes) {
        var paragraphAttributes: Attributes = [:] // 存储应用于整个段落的属性 (如对齐、缩进、段间距)
        // 解析段落级别定义的默认运行属性 <w:pPr><w:rPr>...</w:rPr></w:pPr>
        var defaultRunAttributes: Attributes = parseRunProperties(runPropertyXML: paraPropertyXML["w:rPr"])
        
        let paragraphStyle = NSMutableParagraphStyle() // 用于收集所有段落样式属性
        var alignment: NSTextAlignment = .natural     // 默认自然对齐 (根据书写方向)
        var leftIndent: CGFloat = 0                   // 左缩进 (从页面边距开始算)
        var firstLineHeadIndent: CGFloat = 0          // 首行缩进 (相对于 headIndent)
        // var rightIndent: CGFloat = 0               // 右缩进 (NSParagraphStyle 中通过 tailIndent 间接控制)
        var paragraphSpacingBefore: CGFloat = 0       // 段前间距
        var paragraphSpacingAfter: CGFloat = 0        // 段后间距
        var lineHeightMultiple: CGFloat = 1.0         // 行高倍数 (默认为单倍)
        var minLineHeight: CGFloat? = nil             // 最小行高 (用于 "atLeast" 或 "exact" 行距规则)
        var maxLineHeight: CGFloat? = nil             // 最大行高 (用于 "exact" 行距规则)

        // 对齐方式 <w:jc w:val="..."> ("left", "right", "center", "both"/"justify", "distribute")
        if let alignVal = paraPropertyXML["w:jc"].attributeValue(by: "w:val") {
            switch alignVal.lowercased() { // 转换为小写以进行不区分大小写的比较
            case "left", "start": alignment = .left
            case "right", "end": alignment = .right
            case "center": alignment = .center
            case "both", "distribute", "justify": alignment = .justified // "both", "distribute", "justify" 都视为两端对齐
            default: alignment = .natural // 如果值未知，使用自然对齐
            }
        }
        paragraphStyle.alignment = alignment

        // 缩进 <w:ind ...> (单位: Twips (缇)。1 Point = 20 Twips)
        let twipsPerPoint: CGFloat = 20.0
        let indNode = paraPropertyXML["w:ind"]
        if indNode.element != nil {
            // 左缩进 (w:left 或 w:start 属性)
            if let leftValStr = indNode.attributeValue(by: "w:left") ?? indNode.attributeValue(by: "w:start"),
               let val = Double(leftValStr) {
                leftIndent = CGFloat(val) / twipsPerPoint
            }
            // 右缩进 (w:right 或 w:end 属性) - NSParagraphStyle用tailIndent（通常为负值）
            // if let rightValStr = indNode.attributeValue(by: "w:right") ?? indNode.attributeValue(by: "w:end"),
            //    let val = Double(rightValStr) {
            //     rightIndent = CGFloat(val) / twipsPerPoint
            // }
            // 首行缩进 (w:firstLine 属性) 或 悬挂缩进 (w:hanging 属性)
            if let firstLineValStr = indNode.attributeValue(by: "w:firstLine"),
               let val = Double(firstLineValStr) {
                 firstLineHeadIndent = CGFloat(val) / twipsPerPoint // 正值表示首行额外缩进
            } else if let hangingValStr = indNode.attributeValue(by: "w:hanging"),
                      let val = Double(hangingValStr)  {
                 firstLineHeadIndent = -CGFloat(val) / twipsPerPoint // 悬挂缩进在NSParagraphStyle中表现为负的首行缩进量
             }
        }
        paragraphStyle.headIndent = leftIndent             // 除首行外其他行的头部缩进量
        paragraphStyle.firstLineHeadIndent = firstLineHeadIndent // 首行相对于headIndent的额外（或减少的）缩进量


        // 间距 <w:spacing ...> (单位: Twips)
        if let spacingNode = paraPropertyXML["w:spacing"].element {
            // 段前间距 (w:before 或 w:beforeAutospacing)
            if let beforeStr = spacingNode.attribute(by: "w:before")?.text, let val = Double(beforeStr) {
                paragraphSpacingBefore = CGFloat(val) / twipsPerPoint
            }
            // 段后间距 (w:after 或 w:afterAutospacing)
            if let afterStr = spacingNode.attribute(by: "w:after")?.text, let val = Double(afterStr) {
                paragraphSpacingAfter = CGFloat(val) / twipsPerPoint
            }
            // 行距 (w:line 和 w:lineRule 属性)
             if let lineValStr = spacingNode.attribute(by: "w:line")?.text, let lineVal = Double(lineValStr) {
                 let lineRule = spacingNode.attribute(by: "w:lineRule")?.text.lowercased()
                 switch lineRule {
                 case "auto": // 值以行的 1/240 表示行高倍数
                      lineHeightMultiple = CGFloat(lineVal) / 240.0
                 case "exact": // 值单位为 Twips，表示固定行高
                      let exactHeight = CGFloat(lineVal) / twipsPerPoint
                      minLineHeight = exactHeight
                      maxLineHeight = exactHeight
                 case "atleast": // 值单位为 Twips，表示最小行高
                      minLineHeight = CGFloat(lineVal) / twipsPerPoint
                 default: // 包括 "multiple" (此时lineVal是240的倍数) 或 lineRule 未指定
                      // OOXML "multiple" rule: lineVal is a multiplier of 240ths of a single line.
                      // So, 240 = single, 360 = 1.5 lines, 480 = double.
                      lineHeightMultiple = CGFloat(lineVal) / 240.0
                 }
             }
        }
        paragraphStyle.paragraphSpacingBefore = paragraphSpacingBefore // 段落前间距
        paragraphStyle.paragraphSpacing = paragraphSpacingAfter       // 段落后间距 (NSParagraphStyle的paragraphSpacing指段后)
        
        if let minH = minLineHeight { paragraphStyle.minimumLineHeight = minH } // 设置最小行高
        if let maxH = maxLineHeight { paragraphStyle.maximumLineHeight = maxH } // 设置最大行高 (固定行高时min=max)
        // 只有在不是固定或最小行高时，才设置行高倍数，以避免冲突
        if minLineHeight == nil && maxLineHeight == nil && lineHeightMultiple != 1.0 {
             paragraphStyle.lineHeightMultiple = lineHeightMultiple
        }
        // paragraphStyle.lineSpacing = X // 这是段落内各行之间的额外间距，DOCX中通常通过行高倍数或固定行高控制。
                                      // 如果DOCX段落属性中有显式的<w:spacing w:lineSpacing="Y"/>，则需要转换并设置。
                                      // 目前的解析主要依赖lineHeightMultiple, minimum/maximumLineHeight。
        
        paragraphAttributes[.paragraphStyle] = paragraphStyle // 将配置好的NSParagraphStyle存入段落属性字典

        return (paragraphAttributes, defaultRunAttributes) // 返回段落属性和默认运行属性
    }

    // MARK: - 文本运行处理 (Run Processing)
    // 处理 <w:r> (文本运行) 元素，它是一段具有相同格式的文本。
    private func processRun(runXML: XMLNode, paraProps: (paragraphAttributes: Attributes, runAttributes: Attributes)) throws -> NSAttributedString? {
        let runAttributedString = NSMutableAttributedString()
        // 1. 继承段落的默认运行属性
        var runAttributes = paraProps.runAttributes

        // 2. 解析当前运行特有的属性 (<w:rPr>)，并覆盖/合并到继承的属性中
        let currentRunSpecificAttributes = parseRunProperties(runPropertyXML: runXML["w:rPr"])
        runAttributes.merge(currentRunSpecificAttributes) { (_, new) in new } // new (当前运行的) 属性优先

        // 3. 处理运行内的子元素
        for node in runXML.children {
             if node.element?.name == "w:t" { // 文本内容 <w:t>...</w:t>
                 var text = node.element?.text ?? ""
                 // xml:space="preserve" 属性指示保留文本中的空白字符 (包括前导/尾随空格)
                 // 如果没有此属性，Word通常会根据上下文处理空白，但这里简单处理：不主动trim。
                 // if node.attributeValue(by: "xml:space") != "preserve" {
                 //     text = text.trimmingCharacters(in: .whitespacesAndNewlines) // 这种trim可能过于激进
                 // }
                 runAttributedString.append(NSAttributedString(string: text, attributes: runAttributes))
             } else if node.element?.name == "w:tab" { // 制表符 <w:tab/>
                  runAttributedString.append(NSAttributedString(string: "\t", attributes: runAttributes))
             } else if node.element?.name == "w:br" { // 换行符 <w:br/>
                 // TODO: 处理 <w:br w:type="page"/> 实现分页符 (可能需要特殊字符或回调通知PDF生成器)
                 runAttributedString.append(NSAttributedString(string: "\n", attributes: runAttributes))
             } else if node.element?.name == "w:drawing" || node.element?.name == "w:pict" { // 运行内嵌的图像
                 if let imageString = try processDrawing(drawingXML: node) {
                     runAttributedString.append(imageString)
                 }
             } else if node.element?.name == "w:instrText" { // 域代码文本 (Field Code Text) - 通常表示动态内容如页码、日期
                 // 目前简单显示为占位符或提取其文本
                 let text = node.element?.text ?? "[域代码]"
                 runAttributedString.append(NSAttributedString(string: text, attributes: runAttributes))
             } else if node.element?.name == "w:noBreakHyphen" { // 不间断连字符
                 runAttributedString.append(NSAttributedString(string: "\u{2011}", attributes: runAttributes)) // Unicode U+2011
             }
             // <w:rPr> 是运行属性标签，在开头已处理，此处应忽略。
             // else if node.element?.name != "w:rPr" {
             //     print("跳过未知的运行子元素: \(node.element?.name ?? "nil")")
             // }
        }
        
        return runAttributedString.length > 0 ? runAttributedString : nil // 如果运行内容为空则返回nil
    }

    // MARK: - 文本运行属性解析 (Run Property Parsing)
    // 解析 <w:rPr> (运行属性) 元素，如字体、大小、颜色、粗体、斜体等。
    private func parseRunProperties(runPropertyXML: XMLNode) -> Attributes {
        var attributes: Attributes = [:] // 存储解析出的运行属性
        // 设置默认值
        var fontSize = DocxConstants.defaultFontSize // 从全局默认字号开始
        var fontNameFromDocx: String? = nil         // 文档中指定的字体名称
        var isBold = false                          // 是否加粗
        var isItalic = false                        // 是否斜体
        var isUnderline = false                     // 是否有下划线
        var isStrikethrough = false                 // 是否有删除线
        var foregroundColorHex: String? = nil       // 文本颜色 (十六进制字符串)
        var highlightColorName: String? = nil       // 高亮背景颜色名称 (如 "yellow")
        var verticalAlign: Int = 0                  // 垂直对齐: 0-基线, 1-上标, 2-下标

        // 字号 <w:sz w:val="..."/> (值为半点，例如24表示12磅)
        // <w:szCs w:val="..."/> 用于复杂文种 (Complex Script)
        if let szStr = runPropertyXML["w:sz"].attributeValue(by: "w:val") ?? runPropertyXML["w:szCs"].attributeValue(by: "w:val"),
           let sizeValHalfPoints = Double(szStr) {
            fontSize = CGFloat(sizeValHalfPoints) / 2.0 // 从半点转换为磅
        }

        // 字体名称 <w:rFonts w:ascii="..." w:hAnsi="..." w:eastAsia="..." w:cs="..."/>
        let rFontsNode = runPropertyXML["w:rFonts"]
        // 尝试获取不同字符集的字体名称，优先顺序：ASCII, HAnsi, EastAsia, CS
        fontNameFromDocx = rFontsNode.attributeValue(by: "w:ascii") ??
                           rFontsNode.attributeValue(by: "w:hAnsi") ??
                           rFontsNode.attributeValue(by: "w:eastAsia") ?? // 东亚字体通常更具体
                           rFontsNode.attributeValue(by: "w:cs")        // 复杂文种字体

        // 加粗 <w:b/> (存在即为true) 或 <w:b w:val="false|0|true|1"/>
        // <w:bCs/> 用于复杂文种
        isBold = (runPropertyXML["w:b"].element != nil && runPropertyXML["w:b"].attributeValue(by: "w:val") != "0" && runPropertyXML["w:b"].attributeValue(by: "w:val") != "false") ||
                 (runPropertyXML["w:bCs"].element != nil && runPropertyXML["w:bCs"].attributeValue(by: "w:val") != "0" && runPropertyXML["w:bCs"].attributeValue(by: "w:val") != "false")

        // 斜体 <w:i/> 或 <w:i w:val="..."/>
        // <w:iCs/> 用于复杂文种
        isItalic = (runPropertyXML["w:i"].element != nil && runPropertyXML["w:i"].attributeValue(by: "w:val") != "0" && runPropertyXML["w:i"].attributeValue(by: "w:val") != "false") ||
                   (runPropertyXML["w:iCs"].element != nil && runPropertyXML["w:iCs"].attributeValue(by: "w:val") != "0" && runPropertyXML["w:iCs"].attributeValue(by: "w:val") != "false")

        // 下划线 <w:u w:val="..."/> (val="none" 或 "0" 表示无下划线)
        // TODO: 可以解析 w:val 的具体值 (single, double, wave, etc.) 来设置不同的 NSUnderlineStyle
        if let uNode = runPropertyXML["w:u"].element,
           let uVal = uNode.attribute(by: "w:val"),
           uVal.text.lowercased() != "none", uVal.text != "0" {
            isUnderline = true
        } else if runPropertyXML["w:u"].element != nil && runPropertyXML["w:u"].attributeValue(by: "w:val") == nil {
            isUnderline = true // Just <w:u/> implies single underline
        }
        
        // 删除线 <w:strike/> 或 <w:dstrike/> (双删除线)
        if (runPropertyXML["w:strike"].element != nil && runPropertyXML["w:strike"].attributeValue(by: "w:val") != "0" && runPropertyXML["w:strike"].attributeValue(by: "w:val") != "false") ||
           (runPropertyXML["w:dstrike"].element != nil && runPropertyXML["w:dstrike"].attributeValue(by: "w:val") != "0" && runPropertyXML["w:dstrike"].attributeValue(by: "w:val") != "false") {
            isStrikethrough = true // 双删除线也暂时视为单删除线
        }

        // 文本颜色 <w:color w:val="RRGGBB"/> (val="auto" 表示默认颜色)
        if let colorVal = runPropertyXML["w:color"].attributeValue(by: "w:val"), colorVal.lowercased() != "auto" {
            foregroundColorHex = colorVal
        }
        
        // 高亮颜色 <w:highlight w:val="..."/> (val="none" 表示无高亮)
         if let highlightVal = runPropertyXML["w:highlight"].attributeValue(by: "w:val"), highlightVal.lowercased() != "none" {
             highlightColorName = highlightVal
         }

        // 垂直对齐 (上标/下标) <w:vertAlign w:val="superscript|subscript"/>
        if let vertAlignVal = runPropertyXML["w:vertAlign"].attributeValue(by: "w:val") {
            switch vertAlignVal.lowercased() {
            case "superscript": verticalAlign = 1 // 1 代表上标
            case "subscript": verticalAlign = 2   // 2 代表下标
            default: break // 默认为0 (基线)
            }
        }

        // -- 应用解析出的属性到 NSAttributedString.Key 字典 --
        // 字体和特征 (粗体/斜体)
        var traits: UIFontDescriptor.SymbolicTraits = [] // 用于组合字体特征
        if isBold { traits.insert(.traitBold) }
        if isItalic { traits.insert(.traitItalic) }

        let baseFontName = fontNameFromDocx ?? DocxConstants.defaultFontName // 如果文档未指定，使用全局默认字体
        var finalFont: UIFont?
        if let baseFont = UIFont(name: baseFontName, size: fontSize) { // 尝试创建基础字体
            if !traits.isEmpty, let fontDescriptorWithTraits = baseFont.fontDescriptor.withSymbolicTraits(traits) {
                finalFont = UIFont(descriptor: fontDescriptorWithTraits, size: fontSize) // 应用粗体/斜体特征
            } else {
                finalFont = baseFont // 如果没有特征或无法应用，使用基础字体
            }
        } else { // 如果指定字体名称无效或未找到
            // print("警告: 字体 '\(baseFontName)' 未找到。回退到系统字体。")
            let systemFont = UIFont.systemFont(ofSize: fontSize) // 使用系统默认字体
            if !traits.isEmpty, let fontDescriptorWithTraits = systemFont.fontDescriptor.withSymbolicTraits(traits) {
                finalFont = UIFont(descriptor: fontDescriptorWithTraits, size: fontSize)
            } else {
                finalFont = systemFont
            }
        }
        
        if let font = finalFont { attributes[.font] = font } // 设置字体属性

        // 文本颜色
        if let hex = foregroundColorHex, let color = UIColor(hex: hex) { // 如果指定了颜色且有效
            attributes[.foregroundColor] = color
        } else { // 否则使用默认黑色 (对应 "auto" 或无效颜色值)
            attributes[.foregroundColor] = UIColor.black
        }

        // 下划线和删除线
        if isUnderline { attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue }
        if isStrikethrough { attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue }
        
        // 高亮背景色
        if let hlName = highlightColorName, let hlColor = mapHighlightColor(hlName) {
            attributes[.backgroundColor] = hlColor
        }
        
        // 上标/下标
        if verticalAlign != 0 {
            let actualFontSize = (finalFont ?? UIFont.systemFont(ofSize: fontSize)).pointSize // 获取实际应用的字号
            // 设置基线偏移量：上标为正，下标为负。偏移量通常是字号的一小部分。
            attributes[.baselineOffset] = (verticalAlign == 1) ? (actualFontSize * 0.35) : -(actualFontSize * 0.20)
            // 可选：为上标/下标文本使用稍小一点的字号，以改善视觉效果
            if let smallerFont = finalFont?.withSize(actualFontSize * 0.75) { // 例如，原字号的75%
                attributes[.font] = smallerFont
            }
        }
        return attributes
    }
    
    // MARK: - 超链接处理 (Hyperlink Processing)
    // 处理 <w:hyperlink> 元素
    private func processHyperlink(hyperlinkXML: XMLNode, paraProps: (paragraphAttributes: Attributes, runAttributes: Attributes)) throws -> NSAttributedString? {
        // 1. 获取超链接的关系ID (r:id)，并从已解析的关系中查找目标URL
        guard let relationshipId = hyperlinkXML.attributeValue(by: "r:id"),
              let targetPath = relationships[relationshipId] else {
            // 如果没有ID或目标，则仅将超链接内的文本作为普通文本处理
            // print("警告: 超链接 r:id 或目标路径缺失。作为普通文本处理。")
            let content = NSMutableAttributedString()
            for runNode in hyperlinkXML["w:r"].all { // 遍历超链接内的所有文本运行 <w:r>
                if let runString = try processRun(runXML: runNode, paraProps: paraProps) { content.append(runString) }
            }
            return content.length > 0 ? content : nil
        }
        
        // 2. 根据目标路径创建 URL 对象
        var linkURL: URL?
        if targetPath.starts(with: "http://") || targetPath.starts(with: "https://") || targetPath.starts(with: "mailto:") {
             linkURL = URL(string: targetPath) // 外部URL (网页, 邮件)
        } else if let anchor = hyperlinkXML.attributeValue(by: "w:anchor") { // 内部书签/锚点链接
             // NSAttributedString 对文档内锚点链接的支持不直接，可能需要自定义处理或忽略。
             // print("检测到内部锚点链接: '\(anchor)'，目标: '\(targetPath)'。目前作为文本处理。")
             // 可以考虑使用自定义URL方案或特殊属性来标记内部链接，以便后续处理。
        } else {
            // 可能是指向包内其他文件（如其他文档部分）的相对路径，或无法识别的格式。
            // print("未处理的超链接目标: '\(targetPath)'。作为文本处理。")
        }

        // 3. 处理超链接内显示的文本内容 (通常包含一个或多个 <w:r> 元素)
        let hyperlinkContent = NSMutableAttributedString()
        for runNode in hyperlinkXML["w:r"].all {
            // 超链接文本通常有其特定样式 (例如，在Word中通过名为 "Hyperlink" 的字符样式定义)。
            // processRun 会尝试解析 <w:rPr> 中的样式。如果 <w:rPr> 中指定了 <w:rStyle w:val="Hyperlink"/>，
            // 则需要一个更复杂的样式解析系统来查找并应用 "Hyperlink" 样式。
            // 目前，我们依赖 <w:rPr> 内直接定义的属性或应用默认链接外观。
            if let runString = try processRun(runXML: runNode, paraProps: paraProps) {
                hyperlinkContent.append(runString)
            }
        }

        // 4. 如果成功获取了URL且有显示内容，则为文本应用链接属性和默认外观
        if hyperlinkContent.length > 0 {
            // 默认超链接外观：蓝色文本，带下划线 (仅当未被运行属性显式覆盖时)
            hyperlinkContent.enumerateAttributes(in: NSRange(0..<hyperlinkContent.length), options: []) { attrs, range, _ in
                var applyDefaultLinkStyle = true
                // 如果文本运行本身已定义了特定样式 (例如通过 <w:rStyle> 或直接的 <w:color>, <w:u>)，
                // 我们可能不希望覆盖它。这里做一个简单检查：
                // (更完善的做法是检查是否存在名为 "Hyperlink" 的样式，但这需要解析 styles.xml)
                if attrs[.foregroundColor] != nil && (attrs[.foregroundColor] as? UIColor != UIColor.black) { // 如果颜色不是默认黑色，则认为有特定样式
                    applyDefaultLinkStyle = false
                }
                
                if applyDefaultLinkStyle {
                    // 如果未显式设置颜色，或颜色为默认黑色，则设为蓝色
                    if attrs[.foregroundColor] == nil || (attrs[.foregroundColor] as? UIColor) == .black {
                         hyperlinkContent.addAttribute(.foregroundColor, value: UIColor.blue, range: range)
                    }
                    // 如果未显式设置下划线样式 (包括未设置或设置为 "none")，则添加单下划线
                    if attrs[.underlineStyle] == nil || (attrs[.underlineStyle] as? NSNumber)?.intValue == 0 {
                        hyperlinkContent.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
                    }
                    
                    
                    
                    
                }
            }
            // 如果有合法的URL，则添加 .link 属性
            if let url = linkURL {
                hyperlinkContent.addAttribute(.link, value: url, range: NSRange(location: 0, length: hyperlinkContent.length))
            }
        }
        
        return hyperlinkContent.length > 0 ? hyperlinkContent : nil
    }

    // MARK: - 图像处理 (Drawing/Image Processing)
    // 处理 <w:drawing> (DrawingML) 或 <w:pict> (VML) 元素中嵌入的图像
    private func processDrawing(drawingXML: XMLNode) throws -> NSAttributedString? {
        var embedId: String?    // 图像在关系文件中的 r:id 或 r:embed
        var extentX: Double?    // 图像宽度 (单位: EMU)
        var extentY: Double?    // 图像高度 (单位: EMU)

        // 路径 1: OpenXML DrawingML 格式 (<a:blip r:embed="...">)
        // 通常嵌套在 <w:drawing>/<wp:inline>/<a:graphic>/<a:graphicData>/<pic:pic>/<pic:blipFill>/<a:blip>
        // 或 <w:drawing>/<wp:anchor>/... 类似路径
        let blipSearch = drawingXML.deepSearch(elements: ["a:blip"]) // 深度搜索 "a:blip" 元素
        if let blipNode = blipSearch.first {
            embedId = blipNode.attributeValue(by: "r:embed") // 获取嵌入ID
            // 尝试查找与此 blip 相关的尺寸信息 <wp:extent cx="..." cy="..."/>
            // 尺寸信息可能在 blipNode 的祖先节点中，与 <wp:inline> 或 <wp:anchor> 同级或内部。
            var parentAnchorOrInline = blipNode // 从 blip 开始向上查找
            var extentNode: XMLNode?
            for _ in 0..<6 { // 限制向上搜索的层级，防止无限循环或性能问题
                // 检查当前 parent 是否直接包含 <wp:extent>
                if let currentExtent = parentAnchorOrInline["wp:extent"].element != nil ? parentAnchorOrInline["wp:extent"] : nil {
                    extentNode = currentExtent
                    break
                }
                // 检查当前 parent 是否是 <wp:inline> 或 <wp:anchor>，它们可能包含 <wp:extent>
                if parentAnchorOrInline.element?.name == "wp:inline" || parentAnchorOrInline.element?.name == "wp:anchor" {
                    if let currentExtent = parentAnchorOrInline["wp:extent"].element != nil ? parentAnchorOrInline["wp:extent"] : nil {
                        extentNode = currentExtent
                        break
                    }
                }
                // 向上移动到父节点
                if let p = parentAnchorOrInline.element?.parent { parentAnchorOrInline = XMLIndexer(p) } else { break }
                
                
                               
            }
             if extentNode == nil { // 如果特定路径未找到，则在整个 <w:drawing> 子树中搜索任何 <wp:extent>
                 extentNode = drawingXML.deepSearch(elements: ["wp:extent"]).first
             }

            if let ext = extentNode { // 如果找到了尺寸节点
                extentX = ext.attributeValue(by: "cx").flatMap { Double($0) } // 宽度 cx (EMU)
                extentY = ext.attributeValue(by: "cy").flatMap { Double($0) } // 高度 cy (EMU)
            }
        }
        // 路径 2: VML (Vector Markup Language) 格式的图像 (较旧的 Word 文档中可能存在)
        // <w:pict>/<v:shape>/<v:imagedata r:id="...">
        else if let imageDataNode = drawingXML.deepSearch(elements: ["v:imagedata"]).first {
            embedId = imageDataNode.attributeValue(by: "r:id") // 获取关系ID
            // VML 的尺寸通常在 <v:shape> 的 style 属性中 (例如 "width:100pt;height:50pt")
            if let shapeNode = drawingXML.deepSearch(elements: ["v:shape"]).first,
               let styleString = shapeNode.attributeValue(by: "style") {
                // 尝试从 style 字符串中提取宽度和高度 (单位：磅 pt)
                if let widthInPoints = styleString.extractValue(forKey: "width", unit: "pt") {
                    extentX = Double(widthInPoints * DocxConstants.emuPerPoint) // 转换为 EMU
                }
                if let heightInPoints = styleString.extractValue(forKey: "height", unit: "pt") {
                    extentY = Double(heightInPoints * DocxConstants.emuPerPoint) // 转换为 EMU
                }
            }
        }

        // 必须有 embedId，以及从关系字典中查找到的图像相对路径，和媒体文件的基URL
        guard let id = embedId,
              let imageRelativePath = relationships[id], // 例如 "media/image1.png"
              let base = mediaBaseURL else { // 例如 file:///.../unzipped_docx/word/
            // print("警告: 图像处理失败 - 缺少 embedId ('\(embedId ?? "nil")')、关系或媒体基URL。")
            return NSAttributedString(string: "[图像: 引用信息缺失]")
        }

        // 构建图像文件的完整本地URL
        let imageURL = base.appendingPathComponent(imageRelativePath)
        
        guard FileManager.default.fileExists(atPath: imageURL.path) else {
            // print("警告: 图像文件未在预期路径找到: \(imageURL.path)")
            return NSAttributedString(string: "[图像: 文件 '\(imageRelativePath)' 未找到]")
        }

        // 从文件加载图像
        if let image = UIImage(contentsOfFile: imageURL.path) {
            let textAttachment = NSTextAttachment()
            textAttachment.image = image // 将 UIImage 关联到 NSTextAttachment

            // 设置图像在文本中的显示尺寸 (bounds)
            // 如果从DOCX的XML中成功解析出尺寸 (cx, cy)，并且大于0，则使用这些尺寸。
            // 否则，可以使用图像的固有尺寸，或应用一些默认的最大尺寸限制。
             if let cx = extentX, let cy = extentY, cx > 0, cy > 0 {
                 let widthInPoints = CGFloat(cx / DocxConstants.emuPerPoint)   // EMU 转换为磅
                 let heightInPoints = CGFloat(cy / DocxConstants.emuPerPoint)  // EMU 转换为磅
                 textAttachment.bounds = CGRect(x: 0, y: 0, width: widthInPoints, height: heightInPoints)
                 // print("图像 '\(imageRelativePath)': 应用DOCX尺寸 \(widthInPoints)x\(heightInPoints) 磅")
             } else {
                 // print("图像 '\(imageRelativePath)': 使用图像固有尺寸 \(image.size)。未找到有效的DOCX尺寸信息。")
                 // textAttachment.bounds = CGRect(origin: .zero, size: image.size) // 可选：使用图像原始尺寸
                 // 或者，在这里可以添加逻辑来缩放过大的图片以适应页面宽度，但这通常在PDF渲染阶段处理更好。
             }

            return NSAttributedString(attachment: textAttachment) // 返回包含图像附件的NSAttributedString
        } else {
             // print("警告: 从路径加载图像失败: \(imageURL.path)")
             return NSAttributedString(string: "[图像: 加载失败 '\(imageRelativePath)']")
        }
    }
    
    // MARK: - 辅助函数 (Helper Functions)
    // 将 OOXML 标准高亮颜色名称 (如 "yellow", "lightGray") 映射到 UIColor。
    // OOXML 的高亮通常是半透明的背景色。
    private func mapHighlightColor(_ value: String) -> UIColor? {
         switch value.lowercased() { // 转换为小写以进行不区分大小写的比较
             case "black": return UIColor(white: 0.3, alpha: 0.4) // 黑色高亮通常用深灰色半透明
             case "blue": return UIColor.blue.withAlphaComponent(0.3)
             case "cyan": return UIColor.cyan.withAlphaComponent(0.3)
             case "green": return UIColor.green.withAlphaComponent(0.3)
             case "magenta": return UIColor.magenta.withAlphaComponent(0.3)
             case "red": return UIColor.red.withAlphaComponent(0.3)
             case "yellow": return UIColor.yellow.withAlphaComponent(0.4) // 黄色高亮比较常见
             case "white": return UIColor(white: 0.95, alpha: 0.5) // 白色高亮可能不易察觉，用浅灰色代替
             case "darkblue": return UIColor.blue.withAlphaComponent(0.5) // 深色系列使用稍高的alpha
             case "darkcyan": return UIColor.cyan.withAlphaComponent(0.5)
             case "darkgreen": return UIColor.green.withAlphaComponent(0.5)
             case "darkmagenta": return UIColor.magenta.withAlphaComponent(0.5)
             case "darkred": return UIColor.red.withAlphaComponent(0.5)
             case "darkyellow": return UIColor.yellow.withAlphaComponent(0.6)
             case "darkgray": return UIColor.darkGray.withAlphaComponent(0.4)
             case "lightgray": return UIColor.lightGray.withAlphaComponent(0.4)
             // "none" 表示无高亮，会在调用此函数前被过滤掉。
             default: return nil // 未知或不支持的颜色名称
         }
     }

    // MARK: - PDF Generation (使用我们自定义的手动布局方法)
    /**
     * 将 NSAttributedString 转换为 PDF 数据，使用自定义的布局逻辑。
     * 此方法会处理文本和图片附件的分页和布局。
     * - Parameter attributedString: 要转换为 PDF 的 NSAttributedString。
     * - Parameter outputPathURL: (可选) PDF 文件的保存路径URL。如果提供，PDF将保存到此路径。
     * - Throws: DocParserError 如果 PDF 生成或保存过程中发生错误。
     * - Returns: 表示 PDF 文档的 Data 对象。
     */
    func generatePDFWithCustomLayout(
        attributedString: NSAttributedString,
        outputPathURL: URL? = nil
    ) throws -> Data {
        // 验证输入
        guard attributedString.length > 0 else {
            throw DocParserError.pdfGenerationFailed("输入的 NSAttributedString 为空，无法生成PDF。")
        }

        // 从常量获取PDF页面和边距设置
        let pageRect = DocxConstants.defaultPDFPageRect
        let topMargin = DocxConstants.defaultPDFMargins.top
        let bottomMargin = DocxConstants.defaultPDFMargins.bottom
        let leftMargin = DocxConstants.defaultPDFMargins.left
        let rightMargin = DocxConstants.defaultPDFMargins.right

        // 从常量获取自定义间距设置
        let lineSpacingAfterVisibleText = DocxConstants.pdfLineSpacingAfterVisibleText
        let imageBottomPadding = DocxConstants.pdfImageBottomPadding

        // 计算可打印区域的尺寸
        let printableWidth = pageRect.width - leftMargin - rightMargin
        let printablePageHeight = pageRect.height - topMargin - bottomMargin // 单个页面的最大可打印高度

        // 创建PDF数据缓冲区和上下文
        let pdfData = NSMutableData()
        UIGraphicsBeginPDFContextToData(pdfData, pageRect, nil) // pageRect定义了PDF媒体框
//        defer { UIGraphicsEndPDFContext() } // 确保PDF上下文在函数结束时关闭
        
        // 开始PDF的第一页
        UIGraphicsBeginPDFPageWithInfo(pageRect, nil) // pageRect也用作页面尺寸
        var currentY: CGFloat = topMargin // 初始化当前绘制的Y坐标

        // 辅助函数：开始一个新页面并重置Y坐标
        func startNewPage() {
            UIGraphicsBeginPDFPageWithInfo(pageRect, nil)
            currentY = topMargin
        }

        // 遍历NSAttributedString中的每个属性段
        attributedString.enumerateAttributes(in: NSRange(location: 0, length: attributedString.length), options: []) { attrs, range, _ in
            // --- 处理图片附件 ---
            if let attachment = attrs[.attachment] as? NSTextAttachment, var imageToDraw = attachment.image {
                let originalImageRef = imageToDraw // 保留原始图片引用，用于高质量缩放
                var currentImageSize = imageToDraw.size // 获取图片当前（可能已通过NSTextAttachment.bounds设置）尺寸

                // 步骤 1: 如果图片宽度超过可打印宽度，则按比例缩放以适应宽度
                if currentImageSize.width > printableWidth {
                    let scaleFactor = printableWidth / currentImageSize.width
                    currentImageSize = CGSize(width: printableWidth, height: currentImageSize.height * scaleFactor)
                }
                // 步骤 2: 如果（可能已按宽度缩放后）图片高度仍超过可打印页面高度，则再次按比例缩放以适应高度
                if currentImageSize.height > printablePageHeight {
                    let scaleFactor = printablePageHeight / currentImageSize.height
                    // 注意：这次缩放是基于上一步可能已改变的宽度，所以宽度也会相应缩小
                    currentImageSize = CGSize(width: currentImageSize.width * scaleFactor, height: printablePageHeight)
                }
                
                // 如果计算出的最终尺寸与图片当前尺寸不同，则重新绘制图片到该尺寸
                // 这是为了确保我们绘制的是按最终目标尺寸渲染的图片，而不是依赖UIImage的draw(in:)的自动缩放
                if imageToDraw.size != currentImageSize && currentImageSize.width > 0 && currentImageSize.height > 0 {
                    UIGraphicsBeginImageContextWithOptions(currentImageSize, false, 0.0) // false表示不透明, 0.0表示使用设备scale
                    originalImageRef.draw(in: CGRect(origin: .zero, size: currentImageSize)) // 从原始图片绘制到新尺寸
                    imageToDraw = UIGraphicsGetImageFromCurrentImageContext() ?? originalImageRef // 获取缩放后的图片
                    UIGraphicsEndImageContext()
                }

                // 检查当前页面是否有足够空间绘制此最终缩放后的图片
                // currentY 是当前可以开始绘制的Y点。 imageToDraw.size.height 是图片需要的高度。
                // pageRect.height - bottomMargin 是页面底部边距的上边界。
                if currentY + imageToDraw.size.height > pageRect.height - bottomMargin {
                    // 如果图片放不下，并且当前不是在页面顶部（即页面上已有内容），则换页
                    if currentY > topMargin {
                        startNewPage()
                    }
                    // 如果即使在新页面顶部，图片还是太高（这理论上不应发生，因为已缩放到printablePageHeight），
                    // 则图片可能会被截断，或者我们需要更复杂的错误处理。
                    // 目前，我们假设缩放已确保它适合新页面。
                }
                
                // 绘制最终缩放后的图片
                if imageToDraw.size.height > 0 { // 确保图片有实际高度才绘制
                    let imageDrawRect = CGRect(x: leftMargin, // 图片左边距
                                               y: currentY,     // 当前Y坐标
                                               width: imageToDraw.size.width,
                                               height: imageToDraw.size.height)
                    imageToDraw.draw(in: imageDrawRect) // 在计算出的位置和尺寸绘制图片
                    currentY += imageToDraw.size.height // 更新Y坐标到图片下方
                }
                currentY += imageBottomPadding // 在图片下方添加固定的额外间距

            // --- 处理文本段 ---
            } else if let tableData = attrs[DocParser.tableDrawingDataAttributeKey] as? DocParser.TableDrawingData {
                guard let pdfContext = UIGraphicsGetCurrentContext() else {
                    print("错误：绘制表格时没有PDF图形上下文。")
                    currentY += 20 // 跳过一些空间
                    return // 跳过此表格
                }

                let tableOriginX = leftMargin + tableData.tableIndentation
                var currentTableContentY = currentY // 表格内容开始的Y坐标

                // --- 简单的分页检查：如果表格起始位置太靠下，则换页 ---
                // 注意：这只是一个非常粗略的检查，理想情况下应在计算完所有行高后，
                // 或在绘制每一行之前进行更精确的分页判断。
                let estimatedMinRowHeightPoints: CGFloat = 20 // 假设每行至少20pt高，用于初步分页
                if currentTableContentY + estimatedMinRowHeightPoints > pageRect.height - bottomMargin && currentTableContentY > topMargin {
                    startNewPage()
                    currentTableContentY = topMargin
                }
                currentY = currentTableContentY // 更新全局的 currentY

                // --- 列宽确定 ---
                // 假设 columnWidthsPoints 已经是最终的绘制宽度。
                // 实际应用中可能需要根据 tableTotalAvailableWidth 调整这些宽度 (例如按比例缩放)。
                let columnWidths = tableData.columnWidthsPoints
                let tableActualWidth = columnWidths.reduce(0, +)

                // --- 存储计算出的行Y坐标和行高 ---
                var calculatedRowYOrigins: [CGFloat] = []
                var calculatedRowHeights: [CGFloat] = []

                // --- 第一次遍历：计算每一行的实际高度 ---
                for (rowIndex, rowData) in tableData.rows.enumerated() {
                    var maxCellHeightInRowPoints: CGFloat = 0.0

                    if let specifiedH = rowData.specifiedHeight, specifiedH > 0 {
                        // 如果行高是精确指定的
                        maxCellHeightInRowPoints = specifiedH
                    } else {
                        // 根据单元格内容计算行高
                        for (cellIndexInRow, cellData) in rowData.cells.enumerated() {
                            // 跳过被上方单元格垂直合并覆盖的单元格 (vMerge == .continue)
                            if cellData.vMerge == .continue { continue }

                            var currentCellWidthPoints: CGFloat = 0
                            // 计算此单元格实际占据的宽度 (考虑列合并 gridSpan)
                            for spanIdx in 0..<cellData.gridSpan {
                                if (cellData.originalColIndex + spanIdx) < columnWidths.count {
                                    currentCellWidthPoints += columnWidths[cellData.originalColIndex + spanIdx]
                                }
                            }
                            // 减去单元格内部左右边距
                            let contentWidth = max(1, currentCellWidthPoints - cellData.margins.left - cellData.margins.right)

                            let textBoundingRect = cellData.content.boundingRect(
                                with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
                                options: [.usesLineFragmentOrigin, .usesFontLeading],
                                context: nil
                            )
                            var currentCellRequiredHeightPoints = ceil(textBoundingRect.height)
                            currentCellRequiredHeightPoints += (cellData.margins.top + cellData.margins.bottom) // 加上单元格内部上下边距
                            
                            // 如果此单元格是垂直合并的起始点，它的高度会影响多行，但此处计算的是它在“当前定义行”中所需的高度
                            // 实际的绘制高度会在绘制阶段根据vMerge的跨度来确定
                            maxCellHeightInRowPoints = max(maxCellHeightInRowPoints, currentCellRequiredHeightPoints)
                        }
                        maxCellHeightInRowPoints = max(maxCellHeightInRowPoints, estimatedMinRowHeightPoints) // 保证一个最小行高
                    }
                    calculatedRowHeights.append(max(maxCellHeightInRowPoints, estimatedMinRowHeightPoints)) // 保证一个最小行高
                }


                // --- 第二次遍历：绘制表格的每一行和单元格 ---
                var currentDrawingCellX = tableOriginX

                for (rowIndex, rowData) in tableData.rows.enumerated() {
                    let currentRowHeightPoints = calculatedRowHeights[rowIndex]
                    calculatedRowYOrigins.append(currentY) // 记录当前行的Y起始位置

                    // --- 行级分页检查 ---
                    if currentY + currentRowHeightPoints > pageRect.height - bottomMargin {
                        if currentY > topMargin { // 只有当当前页不是新页的顶部时才换页
                           startNewPage()
                           currentY = topMargin
                           calculatedRowYOrigins[rowIndex] = currentY // 更新换页后的Y起始位置
                        }
                        // 如果即使在新页面，单行还是太高，则可能会被截断。更复杂的行拆分未实现。
                    }
                    
                    currentDrawingCellX = tableOriginX // 每行的起始X坐标重置

                    for (cellIndexInRow, cellData) in rowData.cells.enumerated() {
                        var cellDrawingWidthPoints: CGFloat = 0
                        // 计算此单元格的绘制宽度 (考虑列合并 gridSpan)
                        for spanIdx in 0..<cellData.gridSpan {
                            if (cellData.originalColIndex + spanIdx) < columnWidths.count {
                                cellDrawingWidthPoints += columnWidths[cellData.originalColIndex + spanIdx]
                            }
                        }
                        if cellDrawingWidthPoints <= 0 { cellDrawingWidthPoints = 50 } // 避免宽度为0

                        var cellDrawingHeightPoints = currentRowHeightPoints
                        // 处理垂直合并单元格的绘制高度
                        if cellData.vMerge == .restart {
                            cellDrawingHeightPoints = 0 // 重置，然后累加其覆盖的行高
                            for rIdx in rowIndex..<tableData.rows.count {
                                let spannedRowData = tableData.rows[rIdx]
                                // 找到被合并的单元格
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
                                   (rIdx == rowIndex || actualCellInSpannedRow.vMerge == .continue) { // 是起始行，或者后续行是continue
                                    cellDrawingHeightPoints += calculatedRowHeights[rIdx]
                                } else {
                                    break // 垂直合并结束
                                }
                            }
                        } else if cellData.vMerge == .continue {
                            // 此单元格被上方单元格覆盖，不绘制其背景和内容。
                            // 但它的边框（特别是上边框）可能需要作为内部水平线绘制。
                            // 这里简化处理：只绘制它的上边框（如果适用），然后跳到下一个单元格。

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
                            currentDrawingCellX += cellDrawingWidthPoints // 移动到下一个单元格的X位置
                            continue // 跳过对此 .continue 单元格的其余绘制
                        }


                        let cellDrawingRect = CGRect(x: currentDrawingCellX,
                                                     y: currentY,
                                                     width: cellDrawingWidthPoints,
                                                     height: cellDrawingHeightPoints)

                        // 1. 绘制单元格背景色
                        if let bgColor = cellData.backgroundColor {
                            pdfContext.setFillColor(bgColor.cgColor)
                            pdfContext.fill(cellDrawingRect)
                        }

                        // 2. 绘制单元格边框 (调用辅助函数来决定画哪条以及如何画)
                        //    边框绘制顺序：上、左、下、右，以处理可能的覆盖关系
                        let bordersToDraw = cellData.borders // 使用单元格自身解析的边框
                        
                        // 上边框
                        let topBorder = resolveCellBorder(forEdge: .top, cellData: cellData, rowIndex: rowIndex, cellIndexInRow: cellIndexInRow, tableData: tableData, isFirstRowOfTable: rowIndex == 0, isFirstColOfRow: false)
                        if topBorder.isValid {
                            drawBorderLine(context: pdfContext, start: CGPoint(x: cellDrawingRect.minX, y: cellDrawingRect.minY), end: CGPoint(x: cellDrawingRect.maxX, y: cellDrawingRect.minY), borderInfo: topBorder)
                        }
                        // 左边框
                        let leftBorder = resolveCellBorder(forEdge: .left, cellData: cellData, rowIndex: rowIndex, cellIndexInRow: cellIndexInRow, tableData: tableData, isFirstRowOfTable: false, isFirstColOfRow: cellData.originalColIndex == 0)
                        if leftBorder.isValid {
                             drawBorderLine(context: pdfContext, start: CGPoint(x: cellDrawingRect.minX, y: cellDrawingRect.minY), end: CGPoint(x: cellDrawingRect.minX, y: cellDrawingRect.maxY), borderInfo: leftBorder)
                        }
                        // 下边框 (只有当它是表格的最后一行，或者是被合并单元格的底部时，才使用单元格自身的bottom；否则使用insideH)
                        let bottomBorder = resolveCellBorder(forEdge: .bottom, cellData: cellData, rowIndex: rowIndex, cellIndexInRow: cellIndexInRow, tableData: tableData, isFirstRowOfTable: false, isFirstColOfRow: false, isLastRowOfTable: (rowIndex == tableData.rows.count - 1) || (cellData.vMerge == .restart && (rowIndex + Int(cellDrawingHeightPoints / currentRowHeightPoints) - 1) >= tableData.rows.count - 1) )
                        if bottomBorder.isValid {
                            drawBorderLine(context: pdfContext, start: CGPoint(x: cellDrawingRect.minX, y: cellDrawingRect.maxY), end: CGPoint(x: cellDrawingRect.maxX, y: cellDrawingRect.maxY), borderInfo: bottomBorder)
                        }
                        // 右边框 (只有当它是表格的最后一列，或者是被合并单元格的右部时，才使用单元格自身的right；否则使用insideV)
                        let rightBorder = resolveCellBorder(forEdge: .right, cellData: cellData, rowIndex: rowIndex, cellIndexInRow: cellIndexInRow, tableData: tableData, isFirstRowOfTable: false, isFirstColOfRow: false, isLastColOfTable: (cellData.originalColIndex + cellData.gridSpan >= columnWidths.count))
                        if rightBorder.isValid {
                            drawBorderLine(context: pdfContext, start: CGPoint(x: cellDrawingRect.maxX, y: cellDrawingRect.minY), end: CGPoint(x: cellDrawingRect.maxX, y: cellDrawingRect.maxY), borderInfo: rightBorder)
                        }


                        // 3. 绘制单元格内容 (文本、嵌套图片等)
                        let contentRect = cellDrawingRect.inset(by: cellData.margins) // 应用单元格内边距
                        if contentRect.width > 0 && contentRect.height > 0 {
                            cellData.content.draw(in: contentRect)
                        }
                        
                        currentDrawingCellX += cellDrawingWidthPoints // 移动到下一个单元格的X位置
                    }
                    currentY += currentRowHeightPoints // 移动到下一行的Y位置
                }
                // 表格绘制完毕，添加一些底部间距
                currentY += DocxConstants.pdfLineSpacingAfterVisibleText // 或一个特定的表格后间距
            
            // --- 结束表格处理 ---
            }
            
            else {
                let textSegment = attributedString.attributedSubstring(from: range) // 获取当前属性段的富文本
                let segmentString = textSegment.string // 获取纯字符串，用于判断是否为空白

                // 计算文本段渲染所需的高度
                let textBoundingRect = textSegment.boundingRect(
                    with: CGSize(width: printableWidth, height: .greatestFiniteMagnitude), // 限制宽度，高度不限
                    options: [.usesLineFragmentOrigin, .usesFontLeading], // 必须的选项以正确计算多行文本高度
                    context: nil
                )
                let textHeight = ceil(textBoundingRect.height) // 向上取整，确保足够空间

                // 检查当前文本段是否会超出当前页面的底部边距
                if currentY + textHeight > pageRect.height - bottomMargin {
                    // 如果文本放不下，并且当前不是在页面顶部，则换页
                    if currentY > topMargin {
                       startNewPage()
                    }
                    // 注意：如果单个textSegment（例如一个超长段落）本身就比一页还高，
                    // NSAttributedString.draw(in:) 会自动处理绘制，但超出部分会被截断。
                    // 真正的文本流式续排（reflowing）需要使用CoreText的CTFramesetter。
                }
                
                // 绘制文本段 (只有当计算出的高度大于0时)
                if textHeight > 0 {
                    let drawRect = CGRect(x: leftMargin, y: currentY, width: printableWidth, height: textHeight)
                    textSegment.draw(in: drawRect) // 在计算出的矩形区域内绘制文本
                }
                currentY += textHeight // 更新Y坐标到文本段下方

                // 根据文本内容决定是否添加额外的行间距
                // （例如，我们不希望在纯粹的换行符段落后再添加额外的间距）
                let trimmedSegmentString = segmentString.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmedSegmentString.isEmpty { // 如果修剪后的字符串不为空（即包含可见字符）
                    currentY += lineSpacingAfterVisibleText // 则添加常量定义的额外间距
                }
                // 对于纯粹由空白（如 "\n"）组成的段落，其 textHeight 已包含了该空白行的高度，
                // 所以不再添加 lineSpacingAfterVisibleText (特别是当该常量为0时，无影响)。
            }
        } // 结束 enumerateAttributes 遍历
        UIGraphicsEndPDFContext() // 确保PDF上下文在函数结束时关闭
        // 验证生成的PDF数据是否为空
        guard pdfData.length > 0 else {
            throw DocParserError.pdfGenerationFailed("处理完成后，生成的PDF数据为空。")
        }

        // 如果提供了输出路径URL，则将PDF数据写入文件
        if let url = outputPathURL {
            do {
                try pdfData.write(to: url, options: .atomicWrite) // 原子写入更安全
                print("PDF 已成功保存到: \(url.path)")
            } catch {
                print("保存PDF文件失败: \(error)")
                throw DocParserError.pdfSavingFailed(error)
            }
        }
        guard pdfData.length > 0 else {
            print("错误：最终生成的 PDF 数据为空！") // 添加打印
            throw DocParserError.pdfGenerationFailed("处理完成后，生成的PDF数据为空。")
        }
        print("--- generatePDF: 最终 PDF 数据长度: \(pdfData.length) ---") // 打印最终大小
        return pdfData as Data // 返回PDF数据
    }
    
}

// MARK: - Table Data Structures (表格数据结构)
extension DocParser {

    // 表示垂直单元格合并的状态
    enum VerticalMergeStatus: String {
        case none       // 不是垂直合并的一部分
        case restart    // 此单元格开始一个新的垂直合并
        case `continue` // 此单元格继续一个已存在的垂直合并 (内容通常为空，由 restart 单元格填充)
    }

    // 表示单个边框线 (上, 左, 下, 右)
    struct TableBorderInfo: Equatable {
        enum Style: String {
            case single     // 标准实线
            case double     // 双线 (绘制时需特殊处理)
            case dashed     // 虚线 (绘制时需特殊处理)
            case dotted     // 点线 (绘制时需特殊处理)
            case nilOrNone  // 无边框或显式指定为 "nil" / "none"
            // ... 可以添加其他 OOXML 边框样式 (如: thick, wave 等)
        }

        var style: Style = .nilOrNone
        var width: CGFloat = 0.5 // 点 (points) 为单位的默认宽度 (如果 style 不是 nil/none)
        var color: UIColor = .black
        var space: CGFloat = 0 // 内容与边框的间距 (点)

        static let defaultBorder = TableBorderInfo(style: .single, width: 0.5, color: .black)
        static let noBorder = TableBorderInfo(style: .nilOrNone)

        // 判断此边框是否有效（需要绘制）
        var isValid: Bool { style != .nilOrNone && width > 0 }
    }

    // 存储单元格或表格默认的四边边框信息
    struct TableBorders {
        var top: TableBorderInfo = .noBorder
        var left: TableBorderInfo = .noBorder
        var bottom: TableBorderInfo = .noBorder
        var right: TableBorderInfo = .noBorder
        // 对于表格级默认值，这些很重要:
        var insideHorizontal: TableBorderInfo = .noBorder // 行之间的水平线
        var insideVertical: TableBorderInfo = .noBorder   // 列之间的垂直线
    }

    // 存储单个单元格的绘制所需数据
    struct TableCellDrawingData {
        var content: NSAttributedString         // 解析后的单元格内容
        var borders: TableBorders               // 此单元格最终解析的边框
        var backgroundColor: UIColor?           // 背景色
        var gridSpan: Int = 1                   // 列合并数量 (跨多少列)
        var vMerge: VerticalMergeStatus = .none // 垂直合并状态
        var verticalAlignment: NSTextAlignment = .natural // TODO: 实现真正的垂直对齐 (上/中/下)
        var margins: UIEdgeInsets = .zero       // 单元格内边距 (来自 <w:tcMar>) (点)
        // 用于布局:
        var originalRowIndex: Int = 0           // 在原始表格中的行索引
        var originalColIndex: Int = 0           // 在原始表格中的逻辑列索引（考虑了它前面的列的 gridSpan）
    }

    // 存储表格一行的绘制所需数据
    struct TableRowDrawingData {
        var cells: [TableCellDrawingData]
        var height: CGFloat = 0         // 计算出的或指定的行高 (点)
        var specifiedHeight: CGFloat?   // 从 <w:trHeight w:val="X"> 解析的指定行高 (点)，可能 hRule 是 "exact" 或 "atLeast"
        var isHeaderRow: Bool = false   // 是否为表头行 (来自 <w:tblHeader/>)
    }

    // 存储整个表格的绘制所需数据
    struct TableDrawingData {
        var rows: [TableRowDrawingData]
        var columnWidthsPoints: [CGFloat]    // 每列的宽度 (点)
        var defaultCellBorders: TableBorders // 表格的默认单元格边框 (来自 <w:tblPr><w:tblBorders>)
        var tableIndentation: CGFloat = 0    // 表格的左缩进 (点，来自 <w:tblInd w:w="X" w:type="dxa">)
        // var preferredTableWidth: CGFloat? // TODO: 处理来自 <w:tblW> 的首选表格宽度 (点或百分比)
        // let tableXMLElement: XMLIndexer // 可选：存储原始XML节点，用于调试或高级功能
    }

    // 自定义属性键，用于在 NSAttributedString 中存储 TableDrawingData
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

            let cellBorders = cellData.borders
            let defaultBorders = tableData.defaultCellBorders

            switch edge {
            case .top:
                // 如果是表格的第一行，或者上面单元格是vMerge.continue（意味着一个合并块刚结束），则使用单元格自身的上边框
                // 否则（即内部行），使用 "insideH" 和相邻（上一行）单元格 "bottom" 中更强的那个。
                // 如果单元格自身指定了上边框，则优先使用它。
                if cellBorders.top.style != .nilOrNone { return cellBorders.top } // 单元格指定了就用它的
                if isFirstRowOfTable { return defaultBorders.top.style != .nilOrNone ? defaultBorders.top : cellBorders.top } // 表格首行用表格默认上边框
                 // 内部行，优先用表格的 insideH
                return defaultBorders.insideHorizontal.style != .nilOrNone ? defaultBorders.insideHorizontal : TableBorderInfo.noBorder


            case .left:
                // 如果是行的第一列（考虑gridSpan，应该是originalColIndex == 0），则使用单元格自身的左边框
                // 否则（即内部列），使用 "insideV" 和相邻（左边）单元格 "right" 中更强的那个。
                // 如果单元格自身指定了左边框，则优先使用它。
                if cellBorders.left.style != .nilOrNone { return cellBorders.left }
                if cellData.originalColIndex == 0 { return defaultBorders.left.style != .nilOrNone ? defaultBorders.left : cellBorders.left }
                return defaultBorders.insideVertical.style != .nilOrNone ? defaultBorders.insideVertical : TableBorderInfo.noBorder

            case .bottom:
                if cellBorders.bottom.style != .nilOrNone { return cellBorders.bottom }
                if isLastRowOfTable { return defaultBorders.bottom.style != .nilOrNone ? defaultBorders.bottom : cellBorders.bottom }
                return defaultBorders.insideHorizontal.style != .nilOrNone ? defaultBorders.insideHorizontal : TableBorderInfo.noBorder

            case .right:
                if cellBorders.right.style != .nilOrNone { return cellBorders.right }
                if isLastColOfTable { return defaultBorders.right.style != .nilOrNone ? defaultBorders.right : cellBorders.right }
                return defaultBorders.insideVertical.style != .nilOrNone ? defaultBorders.insideVertical : TableBorderInfo.noBorder
            }
            // 此处简化：如果单元格自己有定义，就用自己的。否则根据位置用表格默认的外部或内部边框。
            // 更完善的逻辑会比较相邻单元格的边框，取“更显著”的那个（例如更粗的线）。
        }


        // 辅助函数：绘制单条边框线
        private func drawBorderLine(context: CGContext, start: CGPoint, end: CGPoint, borderInfo: TableBorderInfo) {
            guard borderInfo.isValid else { return }

            context.saveGState()
            context.setStrokeColor(borderInfo.color.cgColor)
            context.setLineWidth(borderInfo.width)

            // 处理虚线、点线等样式 (非常基础的实现)
            switch borderInfo.style {
            case .dashed:
                // 虚线长度通常是线宽的几倍，例如 3倍线宽的实线，3倍线宽的空白
                let dashPattern: [CGFloat] = [borderInfo.width * 3, borderInfo.width * 3]
                context.setLineDash(phase: 0, lengths: dashPattern)
            case .dotted:
                // 点线可以看作是线宽长度的实线，线宽长度的空白
                let dotPattern: [CGFloat] = [borderInfo.width, borderInfo.width]
                context.setLineDash(phase: 0, lengths: dotPattern)
            case .double:
                // 双线需要绘制两条平行的细线。这里简化为绘制一条稍粗的线，或者需要更复杂的偏移绘制。
                // 暂时画一条线，宽度可能是原始指定宽度，颜色是指定的颜色
                // 若要画两条，需要计算偏移，如：
                // context.setLineWidth(borderInfo.width / 3) // 每条线是总宽度的1/3
                // let offset = borderInfo.width / 3
                // context.move(to: CGPoint(x: start.x, y: start.y - offset))
                // context.addLine(to: CGPoint(x: end.x, y: end.y - offset))
                // context.strokePath()
                // context.move(to: CGPoint(x: start.x, y: start.y + offset))
                // context.addLine(to: CGPoint(x: end.x, y: end.y + offset))
                // context.strokePath()
                // context.restoreGState()
                // return // 双线绘制完成
                break // 默认处理单线
            default: // .single, .nilOrNone (已在isValid中过滤)
                break
            }

            context.move(to: start)
            context.addLine(to: end)
            context.strokePath()
            context.restoreGState()
        }
}




// MARK: - UIColor 十六进制初始化器 (UIColor Hex Initializer)
extension UIColor {
    // 从十六进制字符串 (例如 "RRGGBB" 或 "#RRGGBB") 初始化颜色
    convenience init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines) // 移除首尾空白
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "") // 移除 "#" 前缀

        var rgb: UInt64 = 0 // 用于存储扫描到的十六进制值

        // 使用 Scanner 扫描十六进制整数
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else {
            return nil // 如果扫描失败 (例如字符串不是有效的十六进制)，则初始化失败
        }

        let r, g, b: CGFloat
        // 仅支持6位十六进制 (RRGGBB)
        if hexSanitized.count == 6 {
            r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0 // 提取红色分量
            g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0  // 提取绿色分量
            b = CGFloat(rgb & 0x0000FF) / 255.0         // 提取蓝色分量
        } else {
            // TODO: 可以添加对3位十六进制 (#RGB) 或8位带alpha (#RRGGBBAA) 的支持
            return nil // 目前不支持其他长度的十六进制字符串
        }
        self.init(red: r, green: g, blue: b, alpha: 1.0) // 使用RGB分量初始化UIColor (alpha默认为1.0)
    }
}

// MARK: - XMLIndexer 深度搜索辅助 (XMLIndexer Deep Search Helper)
// 扩展 XMLIndexer 以提供一个简便的方法来深度搜索具有特定名称的子元素。
extension XMLIndexer {
    // 执行广度优先搜索 (BFS)，查找所有匹配指定名称列表的元素。
    // (之前注释为BFS，但实际实现更像DFS或混合，这里保持原意，但通常这种递归或队列操作是BFS或DFS)
    // 修正：这个实现是标准的广度优先搜索 (BFS)
    func deepSearch(elements names: [String]) -> [XMLIndexer] {
        var results: [XMLIndexer] = []      // 存储找到的匹配元素
        var queue: [XMLIndexer] = [self]    // 初始化处理队列，包含当前节点 (搜索起点)

        while !queue.isEmpty { // 当队列不为空时，继续搜索
            let current = queue.removeFirst() // 取出队首元素进行处理
            // 如果当前元素的名称在要查找的名称列表中，则将其添加到结果集
            if let elementName = current.element?.name, names.contains(elementName) {
                results.append(current)
            }
            // 将当前元素的所有直接子元素添加到队列末尾，以供后续处理
            queue.append(contentsOf: current.children)
        }
        return results // 返回所有找到的匹配元素
    }
}


// MARK: - String 扩展，用于 VML 样式解析 (基础)
extension String {
    // 从形如 "key: value unit; key2: value2 unit2" 的样式字符串中提取特定键的值。
    // 例如: 从 "width:100pt;height:50pt" 中调用 extractValue(forKey: "width", unit: "pt") 会返回 100.0。
    func extractValue(forKey key: String, unit: String) -> CGFloat? {
           // 构建正则表达式模式，例如匹配 "width:\s*([0-9.]+)\s*pt"
           // \s* 匹配任意数量的空白字符
           // ([0-9.]+) 捕获组，匹配一个或多个数字或小数点 (表示数值)
           let pattern = "\(key):\\s*([0-9.]+)\\s*\(unit)"
           // 使用不区分大小写的正则匹配
           if let swiftRange = self.range(of: pattern, options: [.regularExpression, .caseInsensitive]) { // 这里得到的是 Range<String.Index>?
               let matchedSubstring = String(self[swiftRange]) // 直接用 Swift Range 提取子串
               // 从匹配到的子串中提取第一个捕获组 (即数值部分)
               // .matches(for:) 应该在 matchedSubstring 上调用
               if let valueString = matchedSubstring.matches(for: pattern).first?.last, // .last是因为捕获组在matches结果的内部数组末尾
                  let value = Double(valueString) { // 将提取到的字符串转换为Double
                   return CGFloat(value) // 返回CGFloat类型的值
               }
           }
           return nil // 如果未找到匹配或转换失败，返回nil
       }


    // 辅助函数：使用正则表达式查找所有匹配项，并返回所有捕获组的字符串。
    // 返回一个二维数组，外层数组对应每个匹配项，内层数组对应每个匹配项中的捕获组 (索引0是整个匹配)。
    func matches(for regex: String) -> [[String]] {
        do {
            let regex = try NSRegularExpression(pattern: regex) // 创建正则表达式对象
            // 在整个字符串范围内查找所有匹配项
            let results = regex.matches(in: self, range: NSRange(self.startIndex..., in: self))
            // 遍历每个匹配结果
            return results.map { result in
                // 遍历每个匹配结果中的所有捕获组 (range at index 0 is the full match)
                return (0..<result.numberOfRanges).map {
                    // 如果捕获组存在 (location != NSNotFound)，则提取其字符串内容
                    result.range(at: $0).location != NSNotFound
                        ? String(self[Range(result.range(at: $0), in: self)!]) // 将NSRange转换为Range并提取子串
                        : "" // 如果捕获组不存在，则返回空字符串
                }
            }
        } catch {
            print("无效的正则表达式 '\(regex)': \(error.localizedDescription)")
            return [] // 如果正则表达式无效，返回空数组
        }
    }

     // 辅助函数：安全地从 NSRange 获取子字符串
     func substring(with nsrange: NSRange) -> String? {
         guard let range = Range(nsrange, in: self) else { return nil } // 将NSRange转换为Swift的Range
         return String(self[range]) // 返回子字符串
     }
}



/*****************************************8888888888888888888888888888888*/
//func generatePDFWithCustomLayout(
//    attributedString: NSAttributedString,
//    outputPathURL: URL? = nil
//) throws -> Data {
//    // 验证输入
//    guard attributedString.length > 0 else {
//        throw DocParserError.pdfGenerationFailed("输入的 NSAttributedString 为空，无法生成PDF。")
//    }
//
//    // 从常量获取PDF页面和边距设置
//    let pageRect = DocxConstants.defaultPDFPageRect
//    let topMargin = DocxConstants.defaultPDFMargins.top
//    let bottomMargin = DocxConstants.defaultPDFMargins.bottom
//    let leftMargin = DocxConstants.defaultPDFMargins.left
//    let rightMargin = DocxConstants.defaultPDFMargins.right
//
//    // 从常量获取自定义间距设置
//    let lineSpacingAfterVisibleText = DocxConstants.pdfLineSpacingAfterVisibleText
//    let imageBottomPadding = DocxConstants.pdfImageBottomPadding
//
//    // 计算可打印区域的尺寸
//    let printableWidth = pageRect.width - leftMargin - rightMargin
//    let printablePageHeight = pageRect.height - topMargin - bottomMargin // 单个页面的最大可打印高度
//
//    // 创建PDF数据缓冲区和上下文
//    let pdfData = NSMutableData()
//    UIGraphicsBeginPDFContextToData(pdfData, pageRect, nil) // pageRect定义了PDF媒体框
//    defer { UIGraphicsEndPDFContext() } // 确保PDF上下文在函数结束时关闭
//    
//    // 开始PDF的第一页
//    UIGraphicsBeginPDFPageWithInfo(pageRect, nil) // pageRect也用作页面尺寸
//    var currentY: CGFloat = topMargin // 初始化当前绘制的Y坐标
//
//    // 辅助函数：开始一个新页面并重置Y坐标
//    func startNewPage() {
//        UIGraphicsBeginPDFPageWithInfo(pageRect, nil)
//        currentY = topMargin
//    }
//
//    // 遍历NSAttributedString中的每个属性段
//    attributedString.enumerateAttributes(in: NSRange(location: 0, length: attributedString.length), options: []) { attrs, range, _ in
//        // --- 处理图片附件 ---
//        if let attachment = attrs[.attachment] as? NSTextAttachment, var imageToDraw = attachment.image {
//            let originalImageRef = imageToDraw // 保留原始图片引用，用于高质量缩放
//            var currentImageSize = imageToDraw.size // 获取图片当前（可能已通过NSTextAttachment.bounds设置）尺寸
//
//            // 步骤 1: 如果图片宽度超过可打印宽度，则按比例缩放以适应宽度
//            if currentImageSize.width > printableWidth {
//                let scaleFactor = printableWidth / currentImageSize.width
//                currentImageSize = CGSize(width: printableWidth, height: currentImageSize.height * scaleFactor)
//            }
//            // 步骤 2: 如果（可能已按宽度缩放后）图片高度仍超过可打印页面高度，则再次按比例缩放以适应高度
//            if currentImageSize.height > printablePageHeight {
//                let scaleFactor = printablePageHeight / currentImageSize.height
//                // 注意：这次缩放是基于上一步可能已改变的宽度，所以宽度也会相应缩小
//                currentImageSize = CGSize(width: currentImageSize.width * scaleFactor, height: printablePageHeight)
//            }
//            
//            // 如果计算出的最终尺寸与图片当前尺寸不同，则重新绘制图片到该尺寸
//            // 这是为了确保我们绘制的是按最终目标尺寸渲染的图片，而不是依赖UIImage的draw(in:)的自动缩放
//            if imageToDraw.size != currentImageSize && currentImageSize.width > 0 && currentImageSize.height > 0 {
//                UIGraphicsBeginImageContextWithOptions(currentImageSize, false, 0.0) // false表示不透明, 0.0表示使用设备scale
//                originalImageRef.draw(in: CGRect(origin: .zero, size: currentImageSize)) // 从原始图片绘制到新尺寸
//                imageToDraw = UIGraphicsGetImageFromCurrentImageContext() ?? originalImageRef // 获取缩放后的图片
//                UIGraphicsEndImageContext()
//            }
//
//            // 检查当前页面是否有足够空间绘制此最终缩放后的图片
//            // currentY 是当前可以开始绘制的Y点。 imageToDraw.size.height 是图片需要的高度。
//            // pageRect.height - bottomMargin 是页面底部边距的上边界。
//            if currentY + imageToDraw.size.height > pageRect.height - bottomMargin {
//                // 如果图片放不下，并且当前不是在页面顶部（即页面上已有内容），则换页
//                if currentY > topMargin {
//                    startNewPage()
//                }
//                // 如果即使在新页面顶部，图片还是太高（这理论上不应发生，因为已缩放到printablePageHeight），
//                // 则图片可能会被截断，或者我们需要更复杂的错误处理。
//                // 目前，我们假设缩放已确保它适合新页面。
//            }
//            
//            // 绘制最终缩放后的图片
//            if imageToDraw.size.height > 0 { // 确保图片有实际高度才绘制
//                let imageDrawRect = CGRect(x: leftMargin, // 图片左边距
//                                           y: currentY,     // 当前Y坐标
//                                           width: imageToDraw.size.width,
//                                           height: imageToDraw.size.height)
//                imageToDraw.draw(in: imageDrawRect) // 在计算出的位置和尺寸绘制图片
//                currentY += imageToDraw.size.height // 更新Y坐标到图片下方
//            }
//            currentY += imageBottomPadding // 在图片下方添加固定的额外间距
//
//        // --- 处理文本段 ---
//        } else if let tableData = attrs[DocParser.tableDrawingDataAttributeKey] as? DocParser.TableDrawingData {
//            guard let pdfContext = UIGraphicsGetCurrentContext() else {
//                print("错误：绘制表格时没有PDF图形上下文。")
//                currentY += 20 // 跳过一些空间
//                return // 跳过此表格
//            }
//
//            let tableOriginX = leftMargin + tableData.tableIndentation
//            var currentTableContentY = currentY // 表格内容开始的Y坐标
//
//            // --- 简单的分页检查：如果表格起始位置太靠下，则换页 ---
//            // 注意：这只是一个非常粗略的检查，理想情况下应在计算完所有行高后，
//            // 或在绘制每一行之前进行更精确的分页判断。
//            let estimatedMinRowHeightPoints: CGFloat = 20 // 假设每行至少20pt高，用于初步分页
//            if currentTableContentY + estimatedMinRowHeightPoints > pageRect.height - bottomMargin && currentTableContentY > topMargin {
//                startNewPage()
//                currentTableContentY = topMargin
//            }
//            currentY = currentTableContentY // 更新全局的 currentY
//
//            // --- 列宽确定 ---
//            // 假设 columnWidthsPoints 已经是最终的绘制宽度。
//            // 实际应用中可能需要根据 tableTotalAvailableWidth 调整这些宽度 (例如按比例缩放)。
//            let columnWidths = tableData.columnWidthsPoints
//            let tableActualWidth = columnWidths.reduce(0, +)
//
//            // --- 存储计算出的行Y坐标和行高 ---
//            var calculatedRowYOrigins: [CGFloat] = []
//            var calculatedRowHeights: [CGFloat] = []
//
//            // --- 第一次遍历：计算每一行的实际高度 ---
//            for (rowIndex, rowData) in tableData.rows.enumerated() {
//                var maxCellHeightInRowPoints: CGFloat = 0.0
//
//                if let specifiedH = rowData.specifiedHeight, specifiedH > 0 {
//                    // 如果行高是精确指定的
//                    maxCellHeightInRowPoints = specifiedH
//                } else {
//                    // 根据单元格内容计算行高
//                    for (cellIndexInRow, cellData) in rowData.cells.enumerated() {
//                        // 跳过被上方单元格垂直合并覆盖的单元格 (vMerge == .continue)
//                        if cellData.vMerge == .continue { continue }
//
//                        var currentCellWidthPoints: CGFloat = 0
//                        // 计算此单元格实际占据的宽度 (考虑列合并 gridSpan)
//                        for spanIdx in 0..<cellData.gridSpan {
//                            if (cellData.originalColIndex + spanIdx) < columnWidths.count {
//                                currentCellWidthPoints += columnWidths[cellData.originalColIndex + spanIdx]
//                            }
//                        }
//                        // 减去单元格内部左右边距
//                        let contentWidth = max(1, currentCellWidthPoints - cellData.margins.left - cellData.margins.right)
//
//                        let textBoundingRect = cellData.content.boundingRect(
//                            with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
//                            options: [.usesLineFragmentOrigin, .usesFontLeading],
//                            context: nil
//                        )
//                        var currentCellRequiredHeightPoints = ceil(textBoundingRect.height)
//                        currentCellRequiredHeightPoints += (cellData.margins.top + cellData.margins.bottom) // 加上单元格内部上下边距
//                        
//                        // 如果此单元格是垂直合并的起始点，它的高度会影响多行，但此处计算的是它在“当前定义行”中所需的高度
//                        // 实际的绘制高度会在绘制阶段根据vMerge的跨度来确定
//                        maxCellHeightInRowPoints = max(maxCellHeightInRowPoints, currentCellRequiredHeightPoints)
//                    }
//                    maxCellHeightInRowPoints = max(maxCellHeightInRowPoints, estimatedMinRowHeightPoints) // 保证一个最小行高
//                }
//                calculatedRowHeights.append(max(maxCellHeightInRowPoints, estimatedMinRowHeightPoints)) // 保证一个最小行高
//            }
//
//
//            // --- 第二次遍历：绘制表格的每一行和单元格 ---
//            var currentDrawingCellX = tableOriginX
//
//            for (rowIndex, rowData) in tableData.rows.enumerated() {
//                let currentRowHeightPoints = calculatedRowHeights[rowIndex]
//                calculatedRowYOrigins.append(currentY) // 记录当前行的Y起始位置
//
//                // --- 行级分页检查 ---
//                if currentY + currentRowHeightPoints > pageRect.height - bottomMargin {
//                    if currentY > topMargin { // 只有当当前页不是新页的顶部时才换页
//                       startNewPage()
//                       currentY = topMargin
//                       calculatedRowYOrigins[rowIndex] = currentY // 更新换页后的Y起始位置
//                    }
//                    // 如果即使在新页面，单行还是太高，则可能会被截断。更复杂的行拆分未实现。
//                }
//                
//                currentDrawingCellX = tableOriginX // 每行的起始X坐标重置
//
//                for (cellIndexInRow, cellData) in rowData.cells.enumerated() {
//                    var cellDrawingWidthPoints: CGFloat = 0
//                    // 计算此单元格的绘制宽度 (考虑列合并 gridSpan)
//                    for spanIdx in 0..<cellData.gridSpan {
//                        if (cellData.originalColIndex + spanIdx) < columnWidths.count {
//                            cellDrawingWidthPoints += columnWidths[cellData.originalColIndex + spanIdx]
//                        }
//                    }
//                    if cellDrawingWidthPoints <= 0 { cellDrawingWidthPoints = 50 } // 避免宽度为0
//
//                    var cellDrawingHeightPoints = currentRowHeightPoints
//                    // 处理垂直合并单元格的绘制高度
//                    if cellData.vMerge == .restart {
//                        cellDrawingHeightPoints = 0 // 重置，然后累加其覆盖的行高
//                        for rIdx in rowIndex..<tableData.rows.count {
//                            let spannedRowData = tableData.rows[rIdx]
//                            // 找到被合并的单元格
//                            var currentLogicalColForSearch = 0
//                            var targetCellInSpannedRow: TableCellDrawingData? = nil
//                            for c_search in spannedRowData.cells {
//                                if currentLogicalColForSearch == cellData.originalColIndex {
//                                    targetCellInSpannedRow = c_search
//                                    break
//                                }
//                                currentLogicalColForSearch += c_search.gridSpan
//                            }
//
//                            if let actualCellInSpannedRow = targetCellInSpannedRow,
//                               (rIdx == rowIndex || actualCellInSpannedRow.vMerge == .continue) { // 是起始行，或者后续行是continue
//                                cellDrawingHeightPoints += calculatedRowHeights[rIdx]
//                            } else {
//                                break // 垂直合并结束
//                            }
//                        }
//                    } else if cellData.vMerge == .continue {
//                        // 此单元格被上方单元格覆盖，不绘制其背景和内容。
//                        // 但它的边框（特别是上边框）可能需要作为内部水平线绘制。
//                        // 这里简化处理：只绘制它的上边框（如果适用），然后跳到下一个单元格。
//
//                        let cellRectForContinue = CGRect(x: currentDrawingCellX, y: currentY, width: cellDrawingWidthPoints, height: currentRowHeightPoints)
//                        let resolvedTopBorder = resolveCellBorder(
//                            forEdge: .top, cellData: cellData, rowIndex: rowIndex, cellIndexInRow: cellIndexInRow,
//                            tableData: tableData, isFirstRowOfTable: rowIndex == 0, isFirstColOfRow: cellIndexInRow == 0
//                        )
//                        if resolvedTopBorder.isValid {
//                            drawBorderLine(context: pdfContext,
//                                           start: CGPoint(x: cellRectForContinue.minX, y: cellRectForContinue.minY),
//                                           end: CGPoint(x: cellRectForContinue.maxX, y: cellRectForContinue.minY),
//                                           borderInfo: resolvedTopBorder)
//                        }
//                        currentDrawingCellX += cellDrawingWidthPoints // 移动到下一个单元格的X位置
//                        continue // 跳过对此 .continue 单元格的其余绘制
//                    }
//
//
//                    let cellDrawingRect = CGRect(x: currentDrawingCellX,
//                                                 y: currentY,
//                                                 width: cellDrawingWidthPoints,
//                                                 height: cellDrawingHeightPoints)
//
//                    // 1. 绘制单元格背景色
//                    if let bgColor = cellData.backgroundColor {
//                        pdfContext.setFillColor(bgColor.cgColor)
//                        pdfContext.fill(cellDrawingRect)
//                    }
//
//                    // 2. 绘制单元格边框 (调用辅助函数来决定画哪条以及如何画)
//                    //    边框绘制顺序：上、左、下、右，以处理可能的覆盖关系
//                    let bordersToDraw = cellData.borders // 使用单元格自身解析的边框
//                    
//                    // 上边框
//                    let topBorder = resolveCellBorder(forEdge: .top, cellData: cellData, rowIndex: rowIndex, cellIndexInRow: cellIndexInRow, tableData: tableData, isFirstRowOfTable: rowIndex == 0, isFirstColOfRow: false)
//                    if topBorder.isValid {
//                        drawBorderLine(context: pdfContext, start: CGPoint(x: cellDrawingRect.minX, y: cellDrawingRect.minY), end: CGPoint(x: cellDrawingRect.maxX, y: cellDrawingRect.minY), borderInfo: topBorder)
//                    }
//                    // 左边框
//                    let leftBorder = resolveCellBorder(forEdge: .left, cellData: cellData, rowIndex: rowIndex, cellIndexInRow: cellIndexInRow, tableData: tableData, isFirstRowOfTable: false, isFirstColOfRow: cellData.originalColIndex == 0)
//                    if leftBorder.isValid {
//                         drawBorderLine(context: pdfContext, start: CGPoint(x: cellDrawingRect.minX, y: cellDrawingRect.minY), end: CGPoint(x: cellDrawingRect.minX, y: cellDrawingRect.maxY), borderInfo: leftBorder)
//                    }
//                    // 下边框 (只有当它是表格的最后一行，或者是被合并单元格的底部时，才使用单元格自身的bottom；否则使用insideH)
//                    let bottomBorder = resolveCellBorder(forEdge: .bottom, cellData: cellData, rowIndex: rowIndex, cellIndexInRow: cellIndexInRow, tableData: tableData, isFirstRowOfTable: false, isFirstColOfRow: false, isLastRowOfTable: (rowIndex == tableData.rows.count - 1) || (cellData.vMerge == .restart && (rowIndex + Int(cellDrawingHeightPoints / currentRowHeightPoints) - 1) >= tableData.rows.count - 1) )
//                    if bottomBorder.isValid {
//                        drawBorderLine(context: pdfContext, start: CGPoint(x: cellDrawingRect.minX, y: cellDrawingRect.maxY), end: CGPoint(x: cellDrawingRect.maxX, y: cellDrawingRect.maxY), borderInfo: bottomBorder)
//                    }
//                    // 右边框 (只有当它是表格的最后一列，或者是被合并单元格的右部时，才使用单元格自身的right；否则使用insideV)
//                    let rightBorder = resolveCellBorder(forEdge: .right, cellData: cellData, rowIndex: rowIndex, cellIndexInRow: cellIndexInRow, tableData: tableData, isFirstRowOfTable: false, isFirstColOfRow: false, isLastColOfTable: (cellData.originalColIndex + cellData.gridSpan >= columnWidths.count))
//                    if rightBorder.isValid {
//                        drawBorderLine(context: pdfContext, start: CGPoint(x: cellDrawingRect.maxX, y: cellDrawingRect.minY), end: CGPoint(x: cellDrawingRect.maxX, y: cellDrawingRect.maxY), borderInfo: rightBorder)
//                    }
//
//
//                    // 3. 绘制单元格内容 (文本、嵌套图片等)
//                    let contentRect = cellDrawingRect.inset(by: cellData.margins) // 应用单元格内边距
//                    if contentRect.width > 0 && contentRect.height > 0 {
//                        cellData.content.draw(in: contentRect)
//                    }
//                    
//                    currentDrawingCellX += cellDrawingWidthPoints // 移动到下一个单元格的X位置
//                }
//                currentY += currentRowHeightPoints // 移动到下一行的Y位置
//            }
//            // 表格绘制完毕，添加一些底部间距
//            currentY += DocxConstants.pdfLineSpacingAfterVisibleText // 或一个特定的表格后间距
//        
//        // --- 结束表格处理 ---
//        }
//        
//        else {
//            let textSegment = attributedString.attributedSubstring(from: range) // 获取当前属性段的富文本
//            let segmentString = textSegment.string // 获取纯字符串，用于判断是否为空白
//
//            // 计算文本段渲染所需的高度
//            let textBoundingRect = textSegment.boundingRect(
//                with: CGSize(width: printableWidth, height: .greatestFiniteMagnitude), // 限制宽度，高度不限
//                options: [.usesLineFragmentOrigin, .usesFontLeading], // 必须的选项以正确计算多行文本高度
//                context: nil
//            )
//            let textHeight = ceil(textBoundingRect.height) // 向上取整，确保足够空间
//
//            // 检查当前文本段是否会超出当前页面的底部边距
//            if currentY + textHeight > pageRect.height - bottomMargin {
//                // 如果文本放不下，并且当前不是在页面顶部，则换页
//                if currentY > topMargin {
//                   startNewPage()
//                }
//                // 注意：如果单个textSegment（例如一个超长段落）本身就比一页还高，
//                // NSAttributedString.draw(in:) 会自动处理绘制，但超出部分会被截断。
//                // 真正的文本流式续排（reflowing）需要使用CoreText的CTFramesetter。
//            }
//            
//            // 绘制文本段 (只有当计算出的高度大于0时)
//            if textHeight > 0 {
//                let drawRect = CGRect(x: leftMargin, y: currentY, width: printableWidth, height: textHeight)
//                textSegment.draw(in: drawRect) // 在计算出的矩形区域内绘制文本
//            }
//            currentY += textHeight // 更新Y坐标到文本段下方
//
//            // 根据文本内容决定是否添加额外的行间距
//            // （例如，我们不希望在纯粹的换行符段落后再添加额外的间距）
//            let trimmedSegmentString = segmentString.trimmingCharacters(in: .whitespacesAndNewlines)
//            if !trimmedSegmentString.isEmpty { // 如果修剪后的字符串不为空（即包含可见字符）
//                currentY += lineSpacingAfterVisibleText // 则添加常量定义的额外间距
//            }
//            // 对于纯粹由空白（如 "\n"）组成的段落，其 textHeight 已包含了该空白行的高度，
//            // 所以不再添加 lineSpacingAfterVisibleText (特别是当该常量为0时，无影响)。
//        }
//    } // 结束 enumerateAttributes 遍历
//
//    // 验证生成的PDF数据是否为空
//    guard pdfData.length > 0 else {
//        throw DocParserError.pdfGenerationFailed("处理完成后，生成的PDF数据为空。")
//    }
//
//    // 如果提供了输出路径URL，则将PDF数据写入文件
//    if let url = outputPathURL {
//        do {
//            try pdfData.write(to: url, options: .atomicWrite) // 原子写入更安全
//            print("PDF 已成功保存到: \(url.path)")
//        } catch {
//            print("保存PDF文件失败: \(error)")
//            throw DocParserError.pdfSavingFailed(error)
//        }
//    }
//    guard pdfData.length > 0 else {
//        print("错误：最终生成的 PDF 数据为空！") // 添加打印
//        throw DocParserError.pdfGenerationFailed("处理完成后，生成的PDF数据为空。")
//    }
//    print("--- generatePDF: 最终 PDF 数据长度: \(pdfData.length) ---") // 打印最终大小
//    return pdfData as Data // 返回PDF数据
//}
