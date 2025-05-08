//
//  ViewController.swift
//  DocParser
//
//  Created by Wesley Yang on 16/4/20.
//  Copyright © 2016年 paf. All rights reserved.
//

import UIKit
import Foundation
import PDFKit

import CoreGraphics

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        let parser = DocParser()
        do{
        
//            let documentPath = NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory.DocumentDirectory,NSSearchPathDomainMask.UserDomainMask, true)
            if let filePath = Bundle.main.url(forResource: "example", withExtension: "docx") {
                print("文件路径：\(filePath)")
                let resultString = try parser.parseFile(fileURL: filePath)
                let pdfURL = FileManager.default.temporaryDirectory.appendingPathComponent("output.pdf")
                try? FileManager.default.removeItem(at: pdfURL)
                

                let pdfData = try? parser.generatePDFWithCustomLayout(
                      attributedString: resultString,
                      outputPathURL: pdfURL // 如果想直接保存文件，传入 URL
                      // outputPathURL: nil        // 如果只想获取 Data 对象，传入 nil
                  )
                  
                
//               try? saveDocToPDF(attributedText: resultString, outputPath: pdfURL.path)
                print("转换成功！PDF 文件路径：\(pdfURL.path)")
                
//                print(resultString)
//                let textView = self.view.viewWithTag(1) as! UITextView
//                textView.attributedText = resultString
                
                let textView = self.view.viewWithTag(1) as! UITextView
                textView.removeFromSuperview()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(3)) {
                    self.openPDF(at: pdfURL)
                }
            }
            
        }catch{
            print(error)
        }
        
    }
    
    // 打开 PDF 文件
       func openPDF(at url: URL) {
           let pdfViewController = UIViewController()
           let pdfView = PDFKit.PDFView(frame: pdfViewController.view.bounds)
           pdfView.autoScales = true
           pdfView.document = PDFKit.PDFDocument(url: url)
           pdfViewController.view.addSubview(pdfView)
           self.present(pdfViewController, animated: true, completion: nil)
       }
    
    func saveDocToPDF(attributedText: NSAttributedString, outputPath: String) throws {
        // 页面尺寸 (US Letter: 8.5 x 11 inches, 1 inch = 72 points)
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        // 页边距
        let topMargin: CGFloat = 40
        let bottomMargin: CGFloat = 40
        let leftMargin: CGFloat = 40
        let rightMargin: CGFloat = 40

        // --- 间距常量 ---
        // 1. 可见文本内容块之后的额外行间距。
        //    设为0则主要依赖NSAttributedString内部换行和段落间距。
        //    根据您的反馈，设置为0以获得更紧凑的布局。
        let lineSpacingAfterVisibleText: CGFloat = 0
        // 2. 图片绘制完成后的底部间距。
        let imageBottomPadding: CGFloat = 10

        // 计算可打印区域的宽度和高度
        let printableWidth = pageRect.width - leftMargin - rightMargin
        let printablePageHeight = pageRect.height - topMargin - bottomMargin // 单个页面的最大可打印高度

        // PDF 数据缓冲区
        let pdfData = NSMutableData()
        // 开始 PDF 上下文
        UIGraphicsBeginPDFContextToData(pdfData, pageRect, nil)
        // 开始第一页
        UIGraphicsBeginPDFPageWithInfo(pageRect, nil)

        // 当前绘制的 Y 坐标
        var currentY: CGFloat = topMargin

        // 辅助函数：开始新页面
        func startNewPage() {
            UIGraphicsBeginPDFPageWithInfo(pageRect, nil)
            currentY = topMargin
        }

        // 遍历 NSAttributedString
        attributedText.enumerateAttributes(in: NSRange(location: 0, length: attributedText.length), options: []) { attrs, range, _ in

            // --- 1. 处理附件 (图片) ---
            if let attachment = attrs[.attachment] as? NSTextAttachment, var imageToDraw = attachment.image {
                let originalImageRef = imageToDraw // 用于在缩放时保持原始比例

                var currentImageSize = imageToDraw.size

                // 步骤 1: 缩放图片以适应可打印宽度 (保持宽高比)
                if currentImageSize.width > printableWidth {
                    let scaleFactor = printableWidth / currentImageSize.width
                    currentImageSize = CGSize(width: printableWidth, height: currentImageSize.height * scaleFactor)
                }

                // 步骤 2: 如果按宽度缩放后仍然太高，则再次缩放以适应可打印页面高度 (保持宽高比)
                // 此时的 currentImageSize 是基于步骤1（如果发生）或原始尺寸的。
                if currentImageSize.height > printablePageHeight {
                    let scaleFactor = printablePageHeight / currentImageSize.height
                    currentImageSize = CGSize(width: currentImageSize.width * scaleFactor, height: printablePageHeight)
                }
                
                // 经过两轮缩放（如果需要），currentImageSize 是最终应该绘制的尺寸
                // 现在用这个最终尺寸从原始图片重新高质量绘制最终的 imageToDraw
                if imageToDraw.size != currentImageSize { // 仅当尺寸发生变化时才重新绘制
                    UIGraphicsBeginImageContextWithOptions(currentImageSize, false, 0.0)
                    originalImageRef.draw(in: CGRect(origin: .zero, size: currentImageSize))
                    imageToDraw = UIGraphicsGetImageFromCurrentImageContext() ?? originalImageRef
                    UIGraphicsEndImageContext()
                }

                // 检查当前页面是否有足够空间绘制此最终缩放后的图片
                if currentY + imageToDraw.size.height > pageRect.height - bottomMargin {
                    if currentY > topMargin {
                        startNewPage()
                    }
                    // 如果换页后图片仍比可打印区域高 (不应该发生，除非图片本身高度为0或边距设置问题)
                    // 或者图片高度大于可打印高度（已在此处缩放，理论上不应大于）
                    // if imageToDraw.size.height > printablePageHeight && currentY == topMargin {
                    //     print("警告: 图片缩放后，在新页面上仍然高于可打印页面高度。这通常不应发生。")
                    // }
                }
                
                // 绘制最终缩放后的图片
                if imageToDraw.size.height > 0 { // 确保图片有高度才绘制
                    let imageDrawRect = CGRect(x: leftMargin, y: currentY, width: imageToDraw.size.width, height: imageToDraw.size.height)
                    imageToDraw.draw(in: imageDrawRect)
                    currentY += imageToDraw.size.height
                }
                currentY += imageBottomPadding // 图片绘制完成后添加固定间距

            }
            // --- 2. 处理文本 ---
            else {
                let textSegment = attributedText.attributedSubstring(from: range)
                let segmentString = textSegment.string

                // DEBUG:
                // print("Text Segment: \"\(segmentString.replacingOccurrences(of: "\n", with: "\\n"))\"")

                // 计算文本高度
                let textBoundingRect = textSegment.boundingRect(
                    with: CGSize(width: printableWidth, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    context: nil
                )
                let textHeight = ceil(textBoundingRect.height)

                // 检查是否需要在绘制文本前换页
                if currentY + textHeight > pageRect.height - bottomMargin {
                    if currentY > topMargin { // 避免文档首个元素过高时产生前导空白页
                       startNewPage()
                    }
                }

                // 绘制文本 (只有当高度大于0时)
                if textHeight > 0 {
                    let drawRect = CGRect(x: leftMargin, y: currentY, width: printableWidth, height: textHeight)
                    textSegment.draw(in: drawRect)
                }
                currentY += textHeight // 加上文本自身的高度

                // 根据文本内容决定是否添加额外行间距
                let trimmedSegmentString = segmentString.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmedSegmentString.isEmpty {
                    // 只有在包含可见字符的文本块之后才添加 lineSpacingAfterVisibleText
                    currentY += lineSpacingAfterVisibleText
                }
                // 对于纯粹的空行（如 "\n" 段），其 textHeight 已包含行高，不再添加额外间距
                // （特别是当 lineSpacingAfterVisibleText 为0时）
            }
        }

        // 结束 PDF 上下文
        UIGraphicsEndPDFContext()
        // 写入文件
        try pdfData.write(to: URL(fileURLWithPath: outputPath), options: .atomicWrite)
        print("PDF 文件保存成功：\(outputPath)")
    }


//    // 调整了图片缩放填充之前的代码
//    func saveDocToPDF(attributedText: NSAttributedString, outputPath: String) throws {
//        // 页面尺寸 (US Letter: 8.5 x 11 inches, 1 inch = 72 points)
//        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
//        // 页边距
//        let topMargin: CGFloat = 40
//        let bottomMargin: CGFloat = 40
//        let leftMargin: CGFloat = 40
//        let rightMargin: CGFloat = 40
//
//        // --- 可调整的间距常量 ---
//        // 全局行间距：仅在包含可见内容的文本块之后添加。
//        // 如果希望主要依赖 NSAttributedString 中的换行符本身来控制间距，可以设为 0 或一个较小的值。
//        let lineSpacingAfterVisibleText: CGFloat = 5
//        // 图片底部的额外间距
//        let imageBottomPadding: CGFloat = 10
//
//        // 计算可打印区域的宽度
//        let printableWidth = pageRect.width - leftMargin - rightMargin
//
//        // PDF 数据缓冲区
//        let pdfData = NSMutableData()
//        // 开始 PDF 上下文
//        UIGraphicsBeginPDFContextToData(pdfData, pageRect, nil)
//        // 开始第一页
//        UIGraphicsBeginPDFPageWithInfo(pageRect, nil)
//
//        // 当前绘制的 Y 坐标
//        var currentY: CGFloat = topMargin
//
//        // 辅助函数：开始新页面
//        func startNewPage() {
//            UIGraphicsBeginPDFPageWithInfo(pageRect, nil)
//            currentY = topMargin
//        }
//
//        // 遍历 NSAttributedString
//        attributedText.enumerateAttributes(in: NSRange(location: 0, length: attributedText.length), options: []) { attrs, range, _ in
//
//            // --- 1. 处理附件 (图片) ---
//            if let attachment = attrs[.attachment] as? NSTextAttachment, let originalImage = attachment.image {
//
//                var imageToDraw = originalImage
//                // 1a. 缩放图片以适应页面宽度
//                if originalImage.size.width > printableWidth {
//                    let scaleFactor = printableWidth / originalImage.size.width
//                    let newHeight = originalImage.size.height * scaleFactor
//                    let newSize = CGSize(width: printableWidth, height: newHeight)
//
//                    UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
//                    originalImage.draw(in: CGRect(origin: .zero, size: newSize))
//                    imageToDraw = UIGraphicsGetImageFromCurrentImageContext() ?? originalImage
//                    UIGraphicsEndImageContext()
//                }
//
//                // 1b. 处理图片高度，必要时进行切割分页
//                var remainingImageHeight = imageToDraw.size.height
//                var imageOffsetY: CGFloat = 0 // 用于从原图中切割的 Y 偏移
//
//                while remainingImageHeight > 0 {
//                    let pageRemainingHeight = pageRect.height - currentY - bottomMargin
//
//                    // 检查是否需要在绘制当前图片片段前换页
//                    if pageRemainingHeight <= imageBottomPadding { // 当前页空间不足以放图片底部间距
//                        // 只有当当前页面已经绘制过内容，或者这不是图片的第一片时才换页
//                        if currentY > topMargin || (remainingImageHeight < imageToDraw.size.height) {
//                             startNewPage()
//                        }
//                    }
//                    // 如果是图片的第一片，且在页面顶部，但图片本身就比一整页还高
//                    else if currentY == topMargin && remainingImageHeight > pageRemainingHeight && remainingImageHeight == imageToDraw.size.height {
//                        // 此时不需要立即换页，因为我们会在当前页绘制第一片
//                    }
//
//
//                    let heightToDrawOnThisPage = min(remainingImageHeight, pageRect.height - currentY - bottomMargin)
//
//                    if heightToDrawOnThisPage <= 0 {
//                        if remainingImageHeight > 0 { // 还有图片未画，但当前页没空间了，强制换页
//                            startNewPage()
//                            // 在新页面上重新计算可绘制高度
//                            let freshPageRemainingHeight = pageRect.height - currentY - bottomMargin
//                            let freshHeightToDraw = min(remainingImageHeight, freshPageRemainingHeight)
//
//                            if freshHeightToDraw <= 0 { // 新页面还是没空间，异常情况
//                                print("警告: 图片在新页面上仍然没有足够的空间绘制。剩余高度: \(remainingImageHeight)")
//                                break // 退出图片绘制循环
//                            }
//                            
//                            let imageDrawRect = CGRect(x: leftMargin, y: currentY, width: imageToDraw.size.width, height: freshHeightToDraw)
//                            if let cgImg = imageToDraw.cgImage?.cropping(to: CGRect(x: 0,
//                                                                                   y: imageOffsetY * imageToDraw.scale,
//                                                                                   width: imageToDraw.size.width * imageToDraw.scale,
//                                                                                   height: freshHeightToDraw * imageToDraw.scale)) {
//                                let slicedImage = UIImage(cgImage: cgImg, scale: imageToDraw.scale, orientation: imageToDraw.imageOrientation)
//                                slicedImage.draw(in: imageDrawRect)
//                            }
//                            currentY += freshHeightToDraw
//                            imageOffsetY += freshHeightToDraw
//                            remainingImageHeight -= freshHeightToDraw
//                            
//                        } else {
//                            break // 没有剩余图片可绘制
//                        }
//                    } else {
//                        // 在当前页绘制图片（或其一部分）
//                        let imageDrawRect = CGRect(x: leftMargin, y: currentY, width: imageToDraw.size.width, height: heightToDrawOnThisPage)
//                        if let cgImg = imageToDraw.cgImage?.cropping(to: CGRect(x: 0,
//                                                                               y: imageOffsetY * imageToDraw.scale,
//                                                                               width: imageToDraw.size.width * imageToDraw.scale,
//                                                                               height: heightToDrawOnThisPage * imageToDraw.scale)) {
//                            let slicedImage = UIImage(cgImage: cgImg, scale: imageToDraw.scale, orientation: imageToDraw.imageOrientation)
//                            slicedImage.draw(in: imageDrawRect)
//                        }
//                        currentY += heightToDrawOnThisPage
//                        imageOffsetY += heightToDrawOnThisPage
//                        remainingImageHeight -= heightToDrawOnThisPage
//                    }
//                    
//                    // 如果图片还有剩余，则准备换页
//                    if remainingImageHeight > 0 {
//                        startNewPage() // 为图片的下一部分开始新页面
//                    }
//                }
//                // 图片（或其最后一部分）绘制完毕后，添加底部间距
//                currentY += imageBottomPadding
//
//            }
//            // --- 2. 处理文本 ---
//            else {
//                let textSegment = attributedText.attributedSubstring(from: range)
//                let segmentString = textSegment.string
//
//                // DEBUG: 打印文本段信息，有助于分析间距问题
//                // print("Text Segment: \"\(segmentString.replacingOccurrences(of: "\n", with: "\\n"))\" (len: \(segmentString.count))")
//
//                // 2a. 计算文本高度
//                let textBoundingRect = textSegment.boundingRect(
//                    with: CGSize(width: printableWidth, height: .greatestFiniteMagnitude),
//                    options: [.usesLineFragmentOrigin, .usesFontLeading],
//                    context: nil
//                )
//                let textHeight = ceil(textBoundingRect.height)
//
//                // 2b. 检查是否需要在绘制文本前换页
//                if currentY + textHeight > pageRect.height - bottomMargin {
//                    if currentY > topMargin { // 避免文档首个元素过高时产生前导空白页
//                       startNewPage()
//                    }
//                    // 如果单个文本块本身就比一页高，会被截断，除非使用 CoreText。
//                }
//
//                // 2c. 绘制文本 (只有当高度大于0时)
//                if textHeight > 0 {
//                    let drawRect = CGRect(x: leftMargin, y: currentY, width: printableWidth, height: textHeight)
//                    textSegment.draw(in: drawRect)
//                }
//                currentY += textHeight // 加上文本自身的高度
//
//                // 2d. 根据文本内容决定是否添加额外行间距
//                let trimmedSegmentString = segmentString.trimmingCharacters(in: .whitespacesAndNewlines)
//                if !trimmedSegmentString.isEmpty {
//                    // 如果文本段包含可见字符，则在其后添加 lineSpacingAfterVisibleText
//                    currentY += lineSpacingAfterVisibleText
//                }
//                // 对于纯粹的空行或仅含空白的段落，不额外添加 lineSpacingAfterVisibleText，
//                // 因为 textHeight 已经包含了该空行的高度。
//            }
//        }
//
//        // 结束 PDF 上下文
//        UIGraphicsEndPDFContext()
//        // 写入文件
//        try pdfData.write(to: URL(fileURLWithPath: outputPath), options: .atomicWrite) // 使用 .atomicWrite 更安全
//        print("PDF 文件保存成功：\(outputPath)")
//    }


    
    
    // 将 NSAttributedString 保存为 PDF 文件
    // attributedText: 要保存的富文本内容
    // outputPath: PDF 文件的保存路径
//    func saveDocToPDF(attributedText: NSAttributedString, outputPath: String) throws {
//        // 定义页面尺寸 (US Letter: 8.5 x 11 inches, 1 inch = 72 points)
//        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
//        // 定义页边距
//        let topMargin: CGFloat = 40
//        let bottomMargin: CGFloat = 40
//        let leftMargin: CGFloat = 40
//        let rightMargin: CGFloat = 40
//        // 文本行间距
//        let lineSpacing: CGFloat = 0
//        // 图片底部的额外间距
//        let imageBottomPadding: CGFloat = 10
//
//        // 计算可打印区域的宽度和高度
//        let printableWidth = pageRect.width - leftMargin - rightMargin
//        // let printableHeight = pageRect.height - topMargin - bottomMargin // (未使用，因为高度是动态消耗的)
//
//        // 创建 PDF 数据缓冲区
//        let pdfData = NSMutableData()
//        // 开始 PDF 上下文，将内容绘制到 pdfData 中
//        UIGraphicsBeginPDFContextToData(pdfData, pageRect, nil)
//        // 开始第一页 (必须在绘制任何内容之前调用)
//        UIGraphicsBeginPDFPageWithInfo(pageRect, nil)
//
//        // 当前绘制的 Y 坐标，从顶部边距开始
//        var currentY: CGFloat = topMargin
//
//        // 辅助函数：开始一个新页面并重置 currentY
//        func startNewPage() {
//            UIGraphicsBeginPDFPageWithInfo(pageRect, nil) // 开始新的一页
//            currentY = topMargin                          // Y 坐标重置到顶部边距
//        }
//
//        // 遍历 NSAttributedString 中的所有属性段
//        attributedText.enumerateAttributes(in: NSRange(location: 0, length: attributedText.length), options: []) { attrs, range, _ in
//
//            // --- 处理附件 (通常是图片) ---
//            if let attachment = attrs[.attachment] as? NSTextAttachment, let originalImage = attachment.image {
//
//                // 1. 如果图片宽度超过可打印宽度，则按比例缩放图片
//                var imageToDraw = originalImage
//                if originalImage.size.width > printableWidth {
//                    let scaleFactor = printableWidth / originalImage.size.width
//                    let newHeight = originalImage.size.height * scaleFactor
//                    let newSize = CGSize(width: printableWidth, height: newHeight)
//
//                    // 创建一个临时图形上下文来缩放图片
//                    UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0) // false 表示不透明, 0.0 表示使用设备主屏幕的 scale
//                    originalImage.draw(in: CGRect(origin: .zero, size: newSize))
//                    imageToDraw = UIGraphicsGetImageFromCurrentImageContext() ?? originalImage // 获取缩放后的图片
//                    UIGraphicsEndImageContext()
//                }
//
//                // 2. 处理可能需要跨页的过高图片
//                var remainingImageHeight = imageToDraw.size.height // 图片剩余需要绘制的高度
//                var imageOffsetY: CGFloat = 0                     // 在原始图片中，当前绘制部分的 Y 轴偏移量 (用于切割)
//
//                while remainingImageHeight > 0 { // 只要图片还有部分未绘制
//                    // 计算当前页面剩余可用于绘制图片的高度
//                    let availableHeightOnPageForImage = pageRect.height - currentY - bottomMargin
//
//                    // 判断是否需要在绘制前换页：
//                    // A. 如果当前页面剩余空间不足以容纳图片的一小部分 (例如，连图片底部间距都放不下)
//                    // B. 或者，如果当前 Y 坐标已经在页面顶部 (currentY == topMargin)，
//                    //    并且 (整个图片 或 图片的剩余部分) 仍然比一整页的可用空间高，说明必须从新页开始切片。
//                    //    `remainingImageHeight == imageToDraw.size.height` 确保这是图片的第一片。
//                    //    `currentY > topMargin` 条件确保如果不是图片的第一片，并且空间不足，则换页。
//                    //    `|| (remainingImageHeight < imageToDraw.size.height)` 确保如果不是第一片，即使在页面顶部，如果放不下也会尝试换页。
//                    if availableHeightOnPageForImage <= imageBottomPadding ||
//                       (currentY == topMargin && remainingImageHeight > availableHeightOnPageForImage) {
//                        // 只有当当前页面已经绘制过内容 (currentY > topMargin)，或者这不是图片的第一片时，才真正开始新页面
//                        // 这是为了避免图片作为文档第一个元素且本身就需要分页时，在最前面产生一个空白页。
//                        if currentY > topMargin || (remainingImageHeight < imageToDraw.size.height) {
//                            startNewPage()
//                        }
//                    }
//                    
//                    // 重新计算换页后的可用高度 (如果发生了换页)
//                    let heightToDrawOnThisPage = min(remainingImageHeight, pageRect.height - currentY - bottomMargin)
//
//                    // 如果计算出的可绘制高度 <= 0，说明当前页实在没空间了
//                    if heightToDrawOnThisPage <= 0 {
//                        if remainingImageHeight > 0 { // 如果还有图片没画完，强制换页
//                            startNewPage()
//                            // 再次计算新页面的可绘制高度
//                            let freshAvailableHeight = pageRect.height - currentY - bottomMargin
//                            let freshHeightToDraw = min(remainingImageHeight, freshAvailableHeight)
//                            
//                            if freshHeightToDraw <= 0 { // 如果新页面还是没空间，可能图片过大或逻辑问题，跳出
//                                print("警告: 图片在新页面上仍然没有足够的空间绘制。剩余高度: \(remainingImageHeight)")
//                                break
//                            }
//                            
//                            // 绘制图片切片
//                            let imageDrawRect = CGRect(x: leftMargin, y: currentY, width: imageToDraw.size.width, height: freshHeightToDraw)
//                            // 从原图中裁剪出当前页要绘制的部分
//                            // 注意: cgImage.cropping 的 rect 是基于像素的，所以需要乘以 imageToDraw.scale
//                            if let cgImg = imageToDraw.cgImage?.cropping(to: CGRect(x: 0,
//                                                                                   y: imageOffsetY * imageToDraw.scale,
//                                                                                   width: imageToDraw.size.width * imageToDraw.scale,
//                                                                                   height: freshHeightToDraw * imageToDraw.scale)) {
//                                let slicedImage = UIImage(cgImage: cgImg, scale: imageToDraw.scale, orientation: imageToDraw.imageOrientation)
//                                slicedImage.draw(in: imageDrawRect)
//                            }
//                            
//                            currentY += freshHeightToDraw + imageBottomPadding // 更新 Y 坐标
//                            imageOffsetY += freshHeightToDraw                   // 更新原图切割偏移
//                            remainingImageHeight -= freshHeightToDraw           // 更新剩余待绘制高度
//                            
//                        } else {
//                            break // 没有剩余图片可绘制
//                        }
//                    } else {
//                        // 当前页面有空间绘制图片（或图片的一部分）
//                        let imageDrawRect = CGRect(x: leftMargin, y: currentY, width: imageToDraw.size.width, height: heightToDrawOnThisPage)
//                        if let cgImg = imageToDraw.cgImage?.cropping(to: CGRect(x: 0,
//                                                                               y: imageOffsetY * imageToDraw.scale,
//                                                                               width: imageToDraw.size.width * imageToDraw.scale,
//                                                                               height: heightToDrawOnThisPage * imageToDraw.scale)) {
//                            let slicedImage = UIImage(cgImage: cgImg, scale: imageToDraw.scale, orientation: imageToDraw.imageOrientation)
//                            slicedImage.draw(in: imageDrawRect)
//                        }
//
//                        currentY += heightToDrawOnThisPage + imageBottomPadding
//                        imageOffsetY += heightToDrawOnThisPage
//                        remainingImageHeight -= heightToDrawOnThisPage
//                    }
//
//                    // 如果图片还有剩余部分，并且当前 Y 坐标已接近或超出页面底部，则准备新页面
//                    // 减去 imageBottomPadding 是为了确保下一片图片在新页面有足够的起始空间
//                    if remainingImageHeight > 0 && currentY >= (pageRect.height - bottomMargin - imageBottomPadding) {
//                         startNewPage()
//                    }
//                }
//            }
//            // --- 处理文本 ---
//            else {
//                let textSegment = attributedText.attributedSubstring(from: range) // 获取当前属性段的文本
//                let segmentString = textSegment.string // 获取段落的纯字符串，方便判断
//                
//                // 计算文本块所需的高度
//                let textBoundingRect = textSegment.boundingRect(with: CGSize(width: printableWidth, height: .greatestFiniteMagnitude),
//                                                                options: [.usesLineFragmentOrigin, .usesFontLeading], // 必须包含 .usesLineFragmentOrigin
//                                                                context: nil)
//                let textHeight = ceil(textBoundingRect.height) //向上取整确保足够空间
//                
//                // 检查当前文本块是否会超出当前页面的底部边距
//                if currentY + textHeight > pageRect.height - bottomMargin {
//                    // 如果当前 Y 坐标大于顶部边距 (意味着当前页已绘制内容)，则开始新的一页
//                    // 这样可以避免文档的第一个元素如果过高，直接导致在最前面生成一个空白页
//                    if currentY > topMargin {
//                        startNewPage()
//                    }
//                    // 如果换页后，单个文本块仍然太高 (例如一个超长的段落比一页还高)，
//                    // NSAttributedString.draw(in:) 会自动处理绘制，但可能只绘制页面能容纳的部分 (即内容会被截断)。
//                    // 要实现文本跨页精确续排，需要使用 CoreText 的 CTFramesetter，那会复杂得多。
//                }
//                
//                // 定义文本绘制的矩形区域
//                let drawRect = CGRect(x: leftMargin, y: currentY, width: printableWidth, height: textHeight)
//                textSegment.draw(in: drawRect) // 绘制文本
//                currentY += textHeight  // 首先加上文本本身的高度
//                // 判断当前文本段是否仅仅是空白行（只包含空格和换行符，且至少有一个换行符）
//                // 如果是，则它本身已经构成了行距，不应再添加额外的全局 lineSpacing
//                let isBlankLineSegment = segmentString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
//                segmentString.rangeOfCharacter(from: .newlines) != nil
//                
//                if !isBlankLineSegment && !segmentString.isEmpty {
//                    // 如果不是空白行段落 (即包含可见字符)，则在它之后添加全局 lineSpacing
//                    currentY += lineSpacing
//                }
//                // 如果是空白行 (isBlankLineSegment is true)，则不添加额外的 lineSpacing，
//                // 因为 textHeight 已经包含了这个空白行的高度。
//                // 如果 segmentString.isEmpty() 为 true (理论上 enumerateAttributes 不会给出完全空的 range，除非原 string 就很奇怪), 也不加 spacing.
//            }
//        }
//
//        // 结束 PDF 上下文
//        UIGraphicsEndPDFContext()
//        // 将 PDF 数据写入文件
//        try pdfData.write(to: URL(fileURLWithPath: outputPath), options: .atomic)
//        print("PDF 文件保存成功：\(outputPath)")
//    }

//    func saveDocToPDF(attributedText: NSAttributedString, outputPath: String) throws {
//        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter
//        let topMargin: CGFloat = 40
//        let bottomMargin: CGFloat = 40
//        let leftMargin: CGFloat = 40
//        let rightMargin: CGFloat = 40
//        let lineSpacing: CGFloat = 5 // Default line spacing for text
//        let imageBottomPadding: CGFloat = 10 // Padding after an image
//
//        let printableWidth = pageRect.width - leftMargin - rightMargin
//        let printableHeight = pageRect.height - topMargin - bottomMargin
//
//        let pdfData = NSMutableData()
//        UIGraphicsBeginPDFContextToData(pdfData, pageRect, nil)
//        UIGraphicsBeginPDFPageWithInfo(pageRect, nil) // Start the first page
//
//        var currentY: CGFloat = topMargin
//
//        // Helper function to start a new page
//        func startNewPage() {
//            UIGraphicsBeginPDFPageWithInfo(pageRect, nil)
//            currentY = topMargin
//        }
//
//        attributedText.enumerateAttributes(in: NSRange(location: 0, length: attributedText.length), options: []) { attrs, range, _ in
//            // --- Handle Attachments (Images) ---
//            if let attachment = attrs[.attachment] as? NSTextAttachment, let originalImage = attachment.image {
//                
//                // 1. Scale image to fit printable width if it's too wide
//                var imageToDraw = originalImage
//                if originalImage.size.width > printableWidth {
//                    let scaleFactor = printableWidth / originalImage.size.width
//                    let newHeight = originalImage.size.height * scaleFactor
//                    let newSize = CGSize(width: printableWidth, height: newHeight)
//                    
//                    UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
//                    originalImage.draw(in: CGRect(origin: .zero, size: newSize))
//                    imageToDraw = UIGraphicsGetImageFromCurrentImageContext() ?? originalImage
//                    UIGraphicsEndImageContext()
//                }
//
//                var remainingImageHeight = imageToDraw.size.height
//                var imageOffsetY: CGFloat = 0 // Y offset within the source image for slicing
//
//                while remainingImageHeight > 0 {
//                    let availableHeightOnPage = pageRect.height - currentY - bottomMargin
//                    
//                    // If no space on current page (or very little, less than a small slice), start new page
//                    // Or if currentY is already at the top of a new page but image still won't fit
//                    if availableHeightOnPage <= imageBottomPadding || (currentY == topMargin && imageToDraw.size.height > availableHeightOnPage && remainingImageHeight == imageToDraw.size.height) {
//                         // Check if currentY is already at topMargin. If so, and the image is too tall for a fresh page,
//                         // it means we are about to draw a slice that requires a new page.
//                         // Or, if it's not the first slice and there's no space.
//                        if currentY > topMargin || (remainingImageHeight < imageToDraw.size.height) { // Avoid new page if it's the very first element and already at top
//                             startNewPage()
//                        }
//                    }
//                    
//                    let heightToDrawOnThisPage = min(remainingImageHeight, pageRect.height - currentY - bottomMargin)
//
//                    if heightToDrawOnThisPage <= 0 { // Should not happen if logic above is correct, but safety
//                        if remainingImageHeight > 0 { // If there's still image to draw, force new page
//                            startNewPage()
//                            // Recalculate heightToDrawOnThisPage for the new page
//                            let freshAvailableHeight = pageRect.height - currentY - bottomMargin
//                            let freshHeightToDraw = min(remainingImageHeight, freshAvailableHeight)
//                            if freshHeightToDraw <= 0 { break } // Still no space, something is wrong or image is too big
//                            
//                            // Draw the slice
//                            let imageRect = CGRect(x: leftMargin, y: currentY, width: imageToDraw.size.width, height: freshHeightToDraw)
//                            // Cropping logic:
//                            if let cgImg = imageToDraw.cgImage?.cropping(to: CGRect(x: 0,
//                                                                                   y: imageOffsetY * imageToDraw.scale, // adjust for image scale
//                                                                                   width: imageToDraw.size.width * imageToDraw.scale,
//                                                                                   height: freshHeightToDraw * imageToDraw.scale)) {
//                                let slicedImage = UIImage(cgImage: cgImg, scale: imageToDraw.scale, orientation: imageToDraw.imageOrientation)
//                                slicedImage.draw(in: imageRect)
//                            }
//                            currentY += freshHeightToDraw + imageBottomPadding
//                            imageOffsetY += freshHeightToDraw
//                            remainingImageHeight -= freshHeightToDraw
//
//                        } else {
//                             break // No more image to draw
//                        }
//                    } else {
//                        // Draw the slice
//                        let imageRect = CGRect(x: leftMargin, y: currentY, width: imageToDraw.size.width, height: heightToDrawOnThisPage)
//                        // Cropping logic:
//                        if let cgImg = imageToDraw.cgImage?.cropping(to: CGRect(x: 0,
//                                                                               y: imageOffsetY * imageToDraw.scale, // adjust for image scale
//                                                                               width: imageToDraw.size.width * imageToDraw.scale,
//                                                                               height: heightToDrawOnThisPage * imageToDraw.scale)) {
//                            let slicedImage = UIImage(cgImage: cgImg, scale: imageToDraw.scale, orientation: imageToDraw.imageOrientation)
//                            slicedImage.draw(in: imageRect)
//                        }
//
//                        currentY += heightToDrawOnThisPage + imageBottomPadding
//                        imageOffsetY += heightToDrawOnThisPage
//                        remainingImageHeight -= heightToDrawOnThisPage
//                    }
//
//                    // If there's more image to draw, and we are at the end of the current page, start a new one
//                    if remainingImageHeight > 0 && currentY >= pageRect.height - bottomMargin - imageBottomPadding {
//                        startNewPage()
//                    }
//                }
//            }
//            // --- Handle Text ---
//            else {
//                let textSegment = attributedText.attributedSubstring(from: range)
//                
//                // Calculate text height
//                let textBoundingRect = textSegment.boundingRect(with: CGSize(width: printableWidth, height: .greatestFiniteMagnitude),
//                                                                 options: [.usesLineFragmentOrigin, .usesFontLeading],
//                                                                 context: nil)
//                let textHeight = ceil(textBoundingRect.height)
//
//                // Check if text fits on the current page
//                if currentY + textHeight > pageRect.height - bottomMargin {
//                    // If currentY is topMargin, it means this text block is too big for a whole page.
//                    // This simplified model will just push it to a new page.
//                    // For true text flow across pages, you'd need a more complex text layout engine (e.g., CoreText framesetter).
//                    // However, NSAttributedString.draw should handle clipping if it's just one very long line.
//                    // The main issue is if a paragraph itself is taller than a page.
//                    if currentY > topMargin { // Only start a new page if we've already drawn something on this one
//                       startNewPage()
//                    }
//                }
//                
//                // If, even on a new page, the single text block is too tall, it will be clipped.
//                // More advanced handling would involve breaking the textSegment itself.
//                // For now, we draw it and let it clip if it's too tall for one page.
//                let drawRect = CGRect(x: leftMargin, y: currentY, width: printableWidth, height: textHeight)
//                textSegment.draw(in: drawRect)
//                currentY += textHeight + lineSpacing
//            }
//        }
//
//        UIGraphicsEndPDFContext()
//        try pdfData.write(to: URL(fileURLWithPath: outputPath), options: .atomic)
//        print("PDF 文件保存成功：\(outputPath)")
//    }



    
    
}

//-(NSString *) getDocumentsDirectory {
//    NSArray *paths = NSSearchPathForDirectoriesInDomains
//    (NSDocumentDirectory, NSUserDomainMask, YES);
//    NSString *documentsDirectory = [paths objectAtIndex:0];
//    return documentsDirectory;
//}
