# DocXParser

## 实现的功能
- 1.解压DOCX、解析XML、处理段落、表格、图片


## 还需要处理的功能
- 1.字体样式
- 2.列表处理
- 3.分页逻辑
续需解析水印元素并添加到 PDF 背景

// MARK: - 表格分页处理说明
// 当前实现暂不支持跨页表格拆分，长表格可能会被截断
// 后续需要实现表格行拆分和跨页续打功能


## 验证功能
段落和文本样式：字体、颜色、粗体、斜体、下划线
表格处理：表格的边框、合并单元格、列宽和行高是否正确计算和绘制。用户实现了自定义的表格绘制逻辑，但需要确认分页时表格是否正确拆分，以及边框样式是否正确应用。
图片处理：图片的尺寸是否正确转换，特别是在PDF中的绘制位置和缩放。用户代码中使用了EMU到点的转换，需要确认计算正确。
分页和布局：在生成PDF时，如何处理内容超出页面高度的情况，是否正确地分页。用户的`generatePDFWithCustomLayout`函数中的分页逻辑是否健壮，特别是对于长表格和图片的处理。
错误处理：现有的错误枚举是否覆盖了所有可能的异常情况，如文件损坏、不支持的样式等

段落处理中，用户处理了段落属性如对齐、缩进、间距，以及运行属性如字体样式。这里可能需要确认是否处理了所有可能的OOXML属性，比如行距的精确控制、首行缩进等。例如，在`parseParagraphProperties`中处理了`w:spacing`，但需要确认是否正确计算了行高倍数和固定行高。

表格处理是重点之一。用户的代码将表格转换为自定义的`TableDrawingData`结构，并在PDF中手动绘制。需要确认列宽的计算是否正确，特别是合并单元格的情况。在`processTable`函数中，用户处理了`w:gridCol`和合并单元格，但可能需要更精确的列宽计算，尤其是在没有网格定义时根据内容自动调整。

图片处理部分，用户从关系文件中获取图片路径，并加载图片，使用EMU转换为点。需要确认EMU转换是否正确，1英寸=914400 EMU，1点=1/72英寸，所以EMU到点的转换应该是除以914400*72？或者用户代码中的`emuPerPoint`是否正确？用户代码中定义为12700，这可能不正确，需要检查。正确的转换应该是1点=12700 EMU（来自OOXML规范），所以用户是正确的。

分页逻辑方面，用户的`generatePDFWithCustomLayout`函数中，当内容超出页面时，会创建新页面。但对于长表格，可能需要将表格拆分成多页，目前的实现可能无法处理，特别是跨页的行的拆分。用户代码中处理了垂直合并，但分页时可能只简单换页，导致表格被截断。这可能需要更复杂的分页处理，比如将表格分成多个部分绘制在不同页面上，但实现起来较复杂，用户可能暂时没有处理，需要添加注释说明当前限制。


错误处理方面，现有的`DocParserError`枚举涵盖了主要错误情况，但可能需要添加更多细节，比如样式解析失败、不支持的边框类型等。


实现styles.xml解析以支持样式继承
添加numbering.xml解析实现完整列表格式
支持跨页表格拆分
实现PDF交互元素（可点击链接）
支持文档分节的不同页面设置
添加水印和页眉页脚支持




好的，我来总结 DOCXReader 处理页眉页脚的核心逻辑：
1.文档结构处理：
    识别文档中的页眉页脚部分
    区分首页、奇数页、偶数页的页眉页脚
    处理不同节的页眉页脚
2.内容解析流程：
    获取页眉页脚部分的内容
    解析段落结构
    处理段落中的文本、图片、表格等元素
    保持内容的层次结构
3.样式处理：
    处理字体属性（字体、大小、颜色等）
    处理段落属性（对齐、缩进、行距等）
    处理主题颜色
    处理边框和背景
4.特殊元素处理：
    页码处理（当前页码、总页数等）
    图片处理（位置、大小、效果等）
    表格处理（结构、样式、合并等）
    日期时间处理
5.布局处理：
    处理页边距
    处理页眉页脚的位置
    处理与正文的关系
    处理不同节的布局
6.数据存储：
    将解析的内容转换为内部文档模型
    保存样式信息
    保存元素关系
    保存布局信息
7.错误处理：
    处理缺失的元素
    处理格式错误
    处理不支持的样式
    处理异常情况
8.性能优化：
    按需加载内容
    缓存常用数据
    优化内存使用
    提高解析效率



你已经构建了一个相当复杂的 DOCX 解析器，并具备了基础的 PDF 生成能力。要更完美地将 DOCX 还原到 PDF，还需要关注以下功能和细节的完善：

I. 布局与分页 (Layout & Pagination):

精确的行高和段间距计算 (Precise Line Height & Paragraph Spacing):

NSParagraphStyle 的完全支持: 确保 lineSpacing, paragraphSpacing, paragraphSpacingBefore, minimumLineHeight, maximumLineHeight, lineHeightMultiple 都被正确解析并应用于 CoreText 的 Framesetter/Frame 计算。

字体度量 (Font Metrics): ascent, descent, leading 对于准确的行定位至关重要。

Word 的行高规则 ("exact", "at least", "multiple"): StyleParser 中对 <w:spacing w:lineRule="..."> 的解析需要精确映射到 NSParagraphStyle 的属性，并在 PDF 渲染时正确体现。

分页符 (Page Breaks):

解析 <w:br w:type="page"/> (段内分页符) 和段落属性中的分页设置（如 <w:pPr><w:pageBreakBefore/></w:pPr>）。

在 generatePDFWithCustomLayout 中，遇到这些标记时强制开始新的一页。

孤行寡行控制 (Widow/Orphan Control):

解析 <w:widowControl/>。这是一个高级特性，意味着在分页时，段落的第一行（寡行）不应单独出现在上一页末尾，段落的最后一行（孤行）不应单独出现在下一页开头。

实现这个需要在分页逻辑中向前或向后查看几行，调整分页点。这比较复杂。

分栏 (Columns):

解析 <w:sectPr><w:cols .../></w:sectPr> (章节属性中的分栏设置)。

PDF 渲染时，需要将内容流分配到多个栏中。CoreText 的 CTFrame 可以基于一个非矩形的 CGPath 创建，这可以用来实现简单的分栏。复杂的分栏可能需要手动管理多个 CTFrame。

页眉页脚 (Headers & Footers):

解析 header[N].xml 和 footer[N].xml 文件及其关系。

每个章节可能有不同的页眉页脚，奇偶页也可能不同。

在 generatePDFWithCustomLayout 的 UIGraphicsBeginPDFPageWithInfo 之后，但在绘制主体内容之前，需要绘制页眉；在绘制完主体内容后，绘制页脚。这需要知道当前页码，并处理字段（如页码 <w:fldChar> + PAGE）。

页面设置 (Page Setup):

解析 <w:sectPr><w:pgSz w:w="..." w:h="..." w:orient="landscape"/> (页面大小和方向)。

解析 <w:sectPr><w:pgMar .../> (页边距)。

将这些值用于 UIGraphicsBeginPDFContextToData 和 UIGraphicsBeginPDFPageWithInfo 的 pageRect，并调整 printableWidth 和 currentY 的起始/结束逻辑。DocxConstants 中的默认值应被文档中的实际值覆盖。

II. 内容元素与格式化 (Content Elements & Formatting):

列表 (Lists - Numbered & Bulleted):

完整解析 numbering.xml: 这个文件定义了列表的格式（数字样式、项目符号字符、缩进、制表位等）。

DocParser 中 processParagraph 对 <w:numPr> 的处理目前是占位符。需要：

根据 <w:numId w:val="..."/> 和 <w:ilvl w:val="..."/> 从 numbering.xml 中查找具体的列表级别定义 (<w:lvl>)。

应用 <w:lvl><w:start .../> (起始编号), <w:lvl><w:numFmt .../> (编号格式), <w:lvl><w:lvlText w:val="..."/> (格式字符串，如 "%1.")。

应用 <w:lvl><w:pPr> 和 <w:lvl><w:rPr> 中定义的缩进和文本样式。

在 PDF 渲染时，正确绘制列表项前缀和文本内容。

制表位 (Tabs):

解析 <w:pPr><w:tabs><w:tab w:val="..." w:pos="..."/></w:tabs>。

NSParagraphStyle 的 tabStops 属性可以设置 NSTextTab 对象。

CoreText 会自动处理基于制表位的文本对齐。

更完善的表格处理 (Enhanced Table Handling):

单元格垂直对齐 (Cell Vertical Alignment): 解析 <w:tcPr><w:vAlign w:val="center|bottom|top"/>。在 PDF 渲染时，调整单元格内文本的垂直位置。

单元格边距的精确应用: 确保 cellData.margins 在计算内容绘制区域时被正确使用。

嵌套表格: 你已经有递归调用 processTable，确保其在 PDF 渲染时也能正确处理。

表格内分页: 如果一个表格行或单元格内容过高，需要能正确地将其分割到下一页。generatePDFWithCustomLayout 中的表格分页逻辑可能需要增强。

表格标题行重复 (Repeat Header Rows): 解析 <w:trPr><w:tblHeader/></w:trPr>。如果表格跨页，标题行应在每页顶部重复。

图片定位与环绕 (Image Positioning & Text Wrapping):

当前图片作为 NSTextAttachment 内联处理。

支持浮动图片 (来自 <wp:anchor>)，包括：

解析其位置（相对于页面、边距、段落等）。

解析文字环绕方式 (<wp:wrapSquare>, <wp:wrapTight>, <wp:wrapThrough>, <wp:wrapTopAndBottom>, <wp:wrapNone>)。

这在 CoreText 中实现起来非常复杂，可能需要手动计算文本流路径，避开图片区域，或者使用更高级的布局引擎。

形状与绘图 (Shapes & Drawings - VML/DrawingML):

除了图片，DOCX还可以包含线条、矩形、文本框等形状。

解析这些形状的属性（大小、位置、填充、边框等）。

在 PDF 中使用 Core Graphics 绘制这些形状。文本框需要将其中的文本也进行解析和渲染。

字段 (Fields - e.g., PAGE, DATE, TOC):

解析 <w:fldChar w:fldCharType="begin|separate|end"/> 和 <w:instrText>...</w:instrText>。

简单字段如 PAGE、NUMPAGES 可以在 PDF 生成时动态计算和替换。

DATE 可以获取当前日期。

目录 (TOC) 生成非常复杂，需要两遍处理：第一遍收集标题和页码，第二遍生成 TOC。

超链接 (Hyperlinks):

你已经有了基础的超链接文本处理。

PDF 中的超链接需要使用 CGPDFContextSetURLForRect (如果直接用 Core Graphics) 或通过 NSAttributedString.Key.link 属性在 UIKit/AppKit 的 PDF 生成框架中自动处理。确保 generatePDFWithCustomLayout 能够利用这些属性。

特殊字符与符号 (Special Characters & Symbols):

你已处理 <w:sym>。确保字体映射和字符代码转换的健壮性。

处理 <w:noBreakHyphen/> (不间断连字符), <w:softHyphen/> (可选连字符) 等。

III. 样式与外观 (Styles & Appearance):

更细致的字体匹配与回退 (Finer Font Matching & Fallback):

当文档请求的字体在系统中不可用时，实现更智能的字体回退策略（例如，基于字体家族、风格等）。

考虑字体替换表。

字符间距与位置 (Character Spacing & Positioning):

解析 <w:rPr><w:spacing w:val="..."/> (字符间距)。NSAttributedString.Key.kern。

解析 <w:rPr><w:position w:val="..."/> (字符垂直位置偏移)。NSAttributedString.Key.baselineOffset。

解析 <w:rPr><w:vertAlign w:val="superscript|subscript"/> (你已处理，确保精确)。

文本效果 (Text Effects):

如阴影 (<w:shadow>)、轮廓 (<w:outline>)、浮雕 (<w:emboss>) 等。这些在 NSAttributedString 中有对应的键，但在 PDF 渲染时可能需要自定义 Core Graphics 绘制。

IV. 结构与元数据 (Structure & Metadata):

文档属性 (Document Properties):

解析 docProps/core.xml (标题、作者、主题等) 和 docProps/app.xml (应用程序特定信息)。

可以将这些信息嵌入到 PDF 的元数据中 (UIGraphicsBeginPDFContextToData 的 documentInfo 字典)。

书签 (Bookmarks):

解析 <w:bookmarkStart w:id="..." w:name="..."/> 和 <w:bookmarkEnd w:id="..."/>。

在 PDF 中创建对应的书签/大纲项。

V. 性能与错误处理 (Performance & Error Handling):

性能优化 (Performance Optimization):

对于非常大的文档，XML 解析和富文本构建可能很慢。考虑流式处理或延迟加载某些部分（如果适用）。

PDF 渲染也可能耗时，特别是有大量复杂图形或表格时。

更全面的错误处理与日志记录 (Comprehensive Error Handling & Logging):

对不支持的特性给出明确的警告或跳过。

记录解析过程中的问题，方便调试。

如何开始：

优先处理对视觉还原影响最大的项：

精确的页面设置和边距。

完善的列表解析和渲染。

更准确的行高和段间距。

分页符。

逐步增加功能：不要试图一次性实现所有。选择一个特性，深入研究其 OOXML 规范，然后实现解析和渲染。

大量测试: 使用各种各样的 DOCX 文件（简单的、复杂的、包含各种特性的）进行测试，对比生成的 PDF 与 Word 中打开的效果。

