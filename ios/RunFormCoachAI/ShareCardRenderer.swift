import UIKit
import Photos

// MARK: - RF-705: Share Card Renderer
//
// Renders standalone share card images using UIGraphicsImageRenderer → UIImage → save to Photos.
// Three card types: analysis result, history record, training plan.
// Aligns with Android ShareCardRenderer.kt (1080×1440 Canvas Bitmap).
//
// Usage:
//   let image = ShareCardRenderer.renderAnalysisCard(result: result, dateLabel: nil)
//   try? await ShareCardRenderer.saveToPhotoLibrary(image)

enum ShareCardRenderer {

    // MARK: - Card dimensions (3:4 aspect ratio, generous size for social sharing)

    private static let cardWidth: CGFloat = 1080
    private static let cardHeight: CGFloat = 1440

    // MARK: - Palette (aligned with Android ShareCardRenderer.kt)

    private static let bgStart   = UIColor(red: 0.02, green: 0.04, blue: 0.09, alpha: 1.0)  // #050A17
    private static let bgEnd     = UIColor(red: 0.03, green: 0.09, blue: 0.17, alpha: 1.0)  // #08172B
    private static let mint      = UIColor(red: 0.25, green: 0.96, blue: 0.76, alpha: 1.0)  // #40F5C2
    private static let cyan      = UIColor(red: 0.10, green: 0.67, blue: 1.00, alpha: 1.0)  // #1AABFF
    private static let orange    = UIColor(red: 1.00, green: 0.62, blue: 0.22, alpha: 1.0)  // #FF9E38
    private static let violet    = UIColor(red: 0.47, green: 0.40, blue: 1.00, alpha: 1.0)  // #7866FF
    private static let red       = UIColor(red: 1.00, green: 0.32, blue: 0.32, alpha: 1.0)  // #FF5252
    private static let textPrimary   = UIColor.white
    private static let textSecondary = UIColor.white.withAlphaComponent(0.63)  // #A0FFFFFF
    private static let textMuted     = UIColor.white.withAlphaComponent(0.38)  // #60FFFFFF
    private static let cardSurface   = UIColor.white.withAlphaComponent(0.09)  // #18FFFFFF
    private static let cardBorder    = UIColor.white.withAlphaComponent(0.13)  // #20FFFFFF
    private static let divider       = UIColor.white.withAlphaComponent(0.08)  // #15FFFFFF

    // MARK: - Standard paddings

    private static let padH: CGFloat = 64
    private static let padV: CGFloat = 56

    // MARK: - Public API

    /// Render an analysis result share card.
    static func renderAnalysisCard(result: AnalysisResponse, dateLabel: String? = nil) -> UIImage {
        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = 1.0
        fmt.opaque = true
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: cardWidth, height: cardHeight), format: fmt)

        return renderer.image { ctx in
            let c = ctx.cgContext
            drawBackground(c)

            var y: CGFloat = padV

            // Header: RunForm Logo + optional timestamp
            y = drawHeader(c, subtitle: dateLabel, topY: y)

            // Divider
            y = drawDivider(c, topY: y, marginTop: 16, marginBottom: 24)

            // Title
            y = drawSectionTitle(c, title: NSLocalizedString("share.card.analysis_title", value: "Analysis Result", comment: ""), topY: y)

            // Overall Score Ring
            let scorePct = Int((result.confidence * 100).rounded())
            y = drawScoreRing(c, label: NSLocalizedString("share.card.overall_score", value: "Overall Score", comment: ""), scorePct: scorePct, topY: y)

            // Key metric rings row
            y = drawMetricRings(c, result: result, topY: y)

            // Key Findings
            if !result.issues.isEmpty {
                y = drawDivider(c, topY: y, marginTop: 12, marginBottom: 20)
                y = drawSectionTitle(c, title: NSLocalizedString("share.card.key_findings", value: "Key Findings", comment: ""), topY: y)
                y = drawFindings(c, result: result, topY: y)
            }

            // Footer
            drawFooter(c)
        }
    }

    /// Render a history record share card.
    static func renderHistoryCard(item: AnalysisHistoryItem, trendData: [Float]? = nil) -> UIImage {
        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = 1.0
        fmt.opaque = true
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: cardWidth, height: cardHeight), format: fmt)

        return renderer.image { ctx in
            let c = ctx.cgContext
            drawBackground(c)

            var y: CGFloat = padV

            // Header with date
            let df = DateFormatter()
            df.dateFormat = "MMM d, yyyy"
            let dateStr = df.string(from: item.createdAt)
            y = drawHeader(c, subtitle: dateStr, topY: y)

            // Divider
            y = drawDivider(c, topY: y, marginTop: 16, marginBottom: 24)

            // Title: "History"
            y = drawSectionTitle(c, title: NSLocalizedString("share.card.history_title", value: "History", comment: ""), topY: y)

            // Date + Score ring
            let scorePct = Int((item.result.confidence * 100).rounded())
            y = drawScoreRing(c, label: dateStr, scorePct: scorePct, topY: y)

            // Summary
            y = drawBodyText(c, text: item.result.summary, topY: y)

            // Trend mini chart
            if let trend = trendData, trend.count >= 2 {
                y = drawDivider(c, topY: y, marginTop: 12, marginBottom: 16)
                y = drawSectionTitle(c, title: NSLocalizedString("share.card.trends", value: "Trends", comment: ""), topY: y)
                y = drawMiniTrendChart(c, data: trend, topY: y)
            }

            // Footer
            drawFooter(c)
        }
    }

    /// Render a training plan share card.
    static func renderPlanCard(plan: TrainingPlanResponse, planType: String) -> UIImage {
        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = 1.0
        fmt.opaque = true
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: cardWidth, height: cardHeight), format: fmt)

        return renderer.image { ctx in
            let c = ctx.cgContext
            drawBackground(c)

            var y: CGFloat = padV

            // Header (no date subtitle for plans)
            y = drawHeader(c, subtitle: nil, topY: y)

            // Divider
            y = drawDivider(c, topY: y, marginTop: 16, marginBottom: 24)

            // Title: plan type
            y = drawSectionTitle(c, title: planType, topY: y)

            // Weekly km + run days badges
            let kmStr = String(format: NSLocalizedString("share.card.weekly_km", value: "%.0f km/week", comment: ""), plan.plannedWeeklyKm)
            let daysStr = String(format: NSLocalizedString("share.card.run_days", value: "%d days", comment: ""), plan.runningDays)
            y = drawPlanStats(c, kmText: kmStr, daysText: daysStr, topY: y)

            // Summary
            y = drawBodyText(c, text: plan.summary.normalizedPlanText, topY: y)

            // Key workouts
            if !plan.workouts.isEmpty {
                y = drawDivider(c, topY: y, marginTop: 12, marginBottom: 16)
                y = drawSectionTitle(c, title: NSLocalizedString("share.card.key_workouts", value: "Key Workouts", comment: ""), topY: y)
                y = drawWorkouts(c, plan: plan, topY: y)
            }

            // Footer
            drawFooter(c)
        }
    }

    /// Save an image to the Photo Library.
    /// - Returns: `true` if saved successfully; throws on authorization or save error.
    @discardableResult
    static func saveToPhotoLibrary(_ image: UIImage) async throws -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw ShareCardError.photoLibraryAccessDenied
        }
        return try await withCheckedThrowingContinuation { continuation in
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            } completionHandler: { success, error in
                if success {
                    continuation.resume(returning: true)
                } else if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(throwing: ShareCardError.photoLibrarySaveFailed)
                }
            }
        }
    }

    // MARK: - Errors

    enum ShareCardError: LocalizedError {
        case photoLibraryAccessDenied
        case photoLibrarySaveFailed

        var errorDescription: String? {
            switch self {
            case .photoLibraryAccessDenied:
                return NSLocalizedString("share.card.error.access_denied", value: "Photo Library access is denied. Please enable it in Settings.", comment: "")
            case .photoLibrarySaveFailed:
                return NSLocalizedString("share.card.error.save_failed", value: "Failed to save image to Photo Library.", comment: "")
            }
        }
    }

    // MARK: - Drawing Helpers

    private static func drawBackground(_ c: CGContext) {
        let colors = [bgStart.cgColor, bgEnd.cgColor] as CFArray
        guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) else { return }
        c.drawLinearGradient(
            gradient,
            start: CGPoint(x: 0, y: 0),
            end: CGPoint(x: 0, y: cardHeight),
            options: []
        )
    }

    private static func drawHeader(_ c: CGContext, subtitle: String?, topY: CGFloat) -> CGFloat {
        var y = topY

        // "RUNFORM" wordmark (centered, bold)
        let logoFont = UIFont.systemFont(ofSize: 42, weight: .bold)
        let logoText = "RUNFORM" as NSString
        let logoAttrs: [NSAttributedString.Key: Any] = [
            .font: logoFont,
            .foregroundColor: textPrimary,
            .kern: NSNumber(value: 0.04 * 42)
        ]
        let logoSize = logoText.size(withAttributes: logoAttrs)
        let logoX = (cardWidth - logoSize.width) / 2
        let logoRect = CGRect(x: logoX, y: y, width: logoSize.width, height: logoSize.height)
        logoText.draw(in: logoRect, withAttributes: logoAttrs)

        // Mint dot after "RUNFORM"
        let dotCenterX = logoX + logoSize.width + 12
        let dotCenterY = y + logoSize.height / 2
        c.setFillColor(mint.cgColor)
        c.fillEllipse(in: CGRect(x: dotCenterX - 5, y: dotCenterY - 5, width: 10, height: 10))

        y += logoSize.height + 4

        // "Injury Prevention Coach" tagline
        let taglineFont = UIFont.systemFont(ofSize: 16)
        let tagline = "Injury Prevention Coach" as NSString
        let taglineAttrs: [NSAttributedString.Key: Any] = [
            .font: taglineFont,
            .foregroundColor: mint,
            .kern: NSNumber(value: 0.12 * 16)
        ]
        let taglineSize = tagline.size(withAttributes: taglineAttrs)
        let taglineRect = CGRect(x: (cardWidth - taglineSize.width) / 2, y: y, width: taglineSize.width, height: taglineSize.height)
        tagline.draw(in: taglineRect, withAttributes: taglineAttrs)

        y += taglineSize.height

        // Optional subtitle (date)
        if let subtitle {
            y += 16
            let subFont = UIFont.systemFont(ofSize: 18)
            let subAttrs: [NSAttributedString.Key: Any] = [
                .font: subFont,
                .foregroundColor: textMuted
            ]
            let subText = subtitle as NSString
            let subSize = subText.size(withAttributes: subAttrs)
            let subRect = CGRect(x: (cardWidth - subSize.width) / 2, y: y, width: subSize.width, height: subSize.height)
            subText.draw(in: subRect, withAttributes: subAttrs)
            y += subSize.height
        }

        return y
    }

    private static func drawDivider(_ c: CGContext, topY: CGFloat, marginTop: CGFloat, marginBottom: CGFloat) -> CGFloat {
        let y = topY + marginTop
        c.setStrokeColor(divider.cgColor)
        c.setLineWidth(1)
        c.move(to: CGPoint(x: padH, y: y))
        c.addLine(to: CGPoint(x: cardWidth - padH, y: y))
        c.strokePath()
        return y + marginBottom
    }

    private static func drawSectionTitle(_ c: CGContext, title: String, topY: CGFloat) -> CGFloat {
        let font = UIFont.systemFont(ofSize: 20, weight: .bold)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: mint,
            .kern: NSNumber(value: 0.08 * 20)
        ]
        let text = title as NSString
        let size = text.size(withAttributes: attrs)
        let rect = CGRect(x: (cardWidth - size.width) / 2, y: topY, width: size.width, height: size.height)
        text.draw(in: rect, withAttributes: attrs)
        return topY + size.height + 24
    }

    private static func drawBodyText(_ c: CGContext, text: String, topY: CGFloat) -> CGFloat {
        let font = UIFont.systemFont(ofSize: 22)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textSecondary
        ]
        let lineHeight: CGFloat = 34
        let maxWidth = cardWidth - padH * 2
        let lines = wrapText(text, font: font, maxWidth: maxWidth).prefix(4)
        var y = topY + 8
        for line in lines {
            let ln = line as NSString
            let size = ln.size(withAttributes: attrs)
            let rect = CGRect(x: (cardWidth - size.width) / 2, y: y, width: size.width, height: size.height)
            ln.draw(in: rect, withAttributes: attrs)
            y += lineHeight
        }
        return y
    }

    // MARK: - Score Ring

    private static func drawScoreRing(_ c: CGContext, label: String, scorePct: Int, topY: CGFloat) -> CGFloat {
        let centerX = cardWidth / 2
        let ringRadius: CGFloat = 100
        let strokeWidth: CGFloat = 16
        let ringTop = topY + 24
        let centerY = ringTop + ringRadius

        let rect = CGRect(x: centerX - ringRadius, y: centerY - ringRadius,
                          width: ringRadius * 2, height: ringRadius * 2)

        // Background ring
        c.setStrokeColor(cardBorder.cgColor)
        c.setLineWidth(strokeWidth)
        c.setLineCap(.round)
        let bgArc = UIBezierPath(arcCenter: CGPoint(x: centerX, y: centerY),
                                  radius: ringRadius, startAngle: -CGFloat.pi / 2,
                                  endAngle: 3 * CGFloat.pi / 2, clockwise: true)
        c.addPath(bgArc.cgPath)
        c.strokePath()

        // Foreground ring
        let ringColor: UIColor = {
            if scorePct >= 75 { return mint }
            if scorePct >= 50 { return orange }
            return red
        }()
        c.setStrokeColor(ringColor.cgColor)
        c.setLineWidth(strokeWidth)
        let sweep = (360.0 * CGFloat(min(max(scorePct, 0), 100)) / 100.0) * CGFloat.pi / 180.0
        let fgArc = UIBezierPath(arcCenter: CGPoint(x: centerX, y: centerY),
                                  radius: ringRadius, startAngle: -CGFloat.pi / 2,
                                  endAngle: -CGFloat.pi / 2 + sweep, clockwise: true)
        c.addPath(fgArc.cgPath)
        c.strokePath()

        // Score text inside ring
        let scoreFont = UIFont.systemFont(ofSize: 48, weight: .bold)
        let scoreAttrs: [NSAttributedString.Key: Any] = [
            .font: scoreFont,
            .foregroundColor: textPrimary
        ]
        let scoreText = "\(scorePct)%" as NSString
        let scoreSize = scoreText.size(withAttributes: scoreAttrs)
        scoreText.draw(at: CGPoint(x: centerX - scoreSize.width / 2, y: centerY - scoreSize.height / 2),
                        withAttributes: scoreAttrs)

        // Label below ring
        let labelFont = UIFont.systemFont(ofSize: 18)
        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: labelFont,
            .foregroundColor: textMuted
        ]
        let labelText = label as NSString
        let labelSize = labelText.size(withAttributes: labelAttrs)
        labelText.draw(at: CGPoint(x: centerX - labelSize.width / 2, y: centerY + ringRadius + 28),
                        withAttributes: labelAttrs)

        return centerY + ringRadius + 48
    }

    // MARK: - Metric Rings (Cadence / Amplitude / GCT)

    private static func drawMetricRings(_ c: CGContext, result: AnalysisResponse, topY: CGFloat) -> CGFloat {
        let metricNames = ["Cadence", "Amplitude", "GCT"]
        let metricColors = [cyan, mint, orange]

        let ringRadius: CGFloat = 72
        let strokeWidth: CGFloat = 12
        let spacing: CGFloat = 40
        let totalW = ringRadius * 2 * 3 + spacing * 2
        let startX = (cardWidth - totalW) / 2 + ringRadius

        var y = topY + 16

        for i in 0..<3 {
            let cx = startX + CGFloat(i) * (ringRadius * 2 + spacing)
            let cy = y + ringRadius

            let metric = result.metrics.indices.contains(i) ? result.metrics[i] : nil
            let scorePct = Int(((metric?.score ?? 0.0) * 100).rounded())
            let name = metric.map { metricNameLabel($0.name, fallback: metricNames[i]) } ?? metricNames[i]

            let rect = CGRect(x: cx - ringRadius, y: cy - ringRadius,
                              width: ringRadius * 2, height: ringRadius * 2)

            // Background ring
            c.setStrokeColor(cardBorder.cgColor)
            c.setLineWidth(strokeWidth)
            c.setLineCap(.round)
            let bgArc = UIBezierPath(arcCenter: CGPoint(x: cx, y: cy),
                                      radius: ringRadius, startAngle: -CGFloat.pi / 2,
                                      endAngle: 3 * CGFloat.pi / 2, clockwise: true)
            c.addPath(bgArc.cgPath)
            c.strokePath()

            // Foreground ring
            c.setStrokeColor(metricColors[i].cgColor)
            c.setLineWidth(strokeWidth)
            let sweep = (360.0 * CGFloat(min(max(scorePct, 0), 100)) / 100.0) * CGFloat.pi / 180.0
            let fgArc = UIBezierPath(arcCenter: CGPoint(x: cx, y: cy),
                                      radius: ringRadius, startAngle: -CGFloat.pi / 2,
                                      endAngle: -CGFloat.pi / 2 + sweep, clockwise: true)
            c.addPath(fgArc.cgPath)
            c.strokePath()

            // Score text
            let scFont = UIFont.systemFont(ofSize: 28, weight: .bold)
            let scAttrs: [NSAttributedString.Key: Any] = [
                .font: scFont,
                .foregroundColor: metricColors[i]
            ]
            let scText = "\(scorePct)%" as NSString
            let scSize = scText.size(withAttributes: scAttrs)
            scText.draw(at: CGPoint(x: cx - scSize.width / 2, y: cy - scSize.height / 2),
                         withAttributes: scAttrs)

            // Label
            let lbFont = UIFont.systemFont(ofSize: 16)
            let lbAttrs: [NSAttributedString.Key: Any] = [
                .font: lbFont,
                .foregroundColor: textMuted
            ]
            let lbText = name as NSString
            let lbSize = lbText.size(withAttributes: lbAttrs)
            lbText.draw(at: CGPoint(x: cx - lbSize.width / 2, y: cy + ringRadius + 26),
                         withAttributes: lbAttrs)
        }

        return y + ringRadius * 2 + 46
    }

    private static func metricNameLabel(_ apiName: String, fallback: String) -> String {
        let lower = apiName.lowercased()
        if lower.contains("cadence") { return "Cadence" }
        if lower.contains("amplitude") || lower.contains("oscillation") { return "Amplitude" }
        if lower.contains("ground") || lower.contains("gct") { return "GCT" }
        return String(apiName.prefix(12))
    }

    // MARK: - Key Findings

    private static func drawFindings(_ c: CGContext, result: AnalysisResponse, topY: CGFloat) -> CGFloat {
        var y = topY
        let font = UIFont.systemFont(ofSize: 20)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textSecondary
        ]
        let lineH: CGFloat = 36

        for issue in result.issues.prefix(3) {
            let text = "• \(issue.title)" as NSString
            let lines = wrapText(text as String, font: font, maxWidth: cardWidth - padH * 2)
            for line in lines {
                let ln = line as NSString
                let size = ln.size(withAttributes: attrs)
                let rect = CGRect(x: padH, y: y, width: size.width, height: size.height)
                ln.draw(in: rect, withAttributes: attrs)
                y += lineH
            }
        }
        return y + 8
    }

    // MARK: - Plan Stats

    private static func drawPlanStats(_ c: CGContext, kmText: String, daysText: String, topY: CGFloat) -> CGFloat {
        let y = topY + 16
        let cardW = (cardWidth - padH * 2 - 24) / 2
        let cardH: CGFloat = 100
        let corner: CGFloat = 24

        let leftX = padH
        let rightX = padH + cardW + 24

        drawStatCard(c, x: leftX, y: y, w: cardW, h: cardH, corner: corner, text: kmText, accentColor: mint)
        drawStatCard(c, x: rightX, y: y, w: cardW, h: cardH, corner: corner, text: daysText, accentColor: cyan)

        return y + cardH + 32
    }

    private static func drawStatCard(_ c: CGContext, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, corner: CGFloat, text: String, accentColor: UIColor) {
        let rect = CGRect(x: x, y: y, width: w, height: h)
        let path = UIBezierPath(roundedRect: rect, cornerRadius: corner)

        // Fill
        c.setFillColor(cardSurface.cgColor)
        c.addPath(path.cgPath)
        c.fillPath()

        // Border
        c.setStrokeColor(cardBorder.cgColor)
        c.setLineWidth(1)
        c.addPath(path.cgPath)
        c.strokePath()

        // Text
        let font = UIFont.systemFont(ofSize: 28, weight: .bold)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: accentColor
        ]
        let nsText = text as NSString
        let textSize = nsText.size(withAttributes: attrs)
        nsText.draw(at: CGPoint(x: x + (w - textSize.width) / 2, y: y + h / 2 - textSize.height / 2),
                     withAttributes: attrs)
    }

    // MARK: - Key Workouts

    private static func drawWorkouts(_ c: CGContext, plan: TrainingPlanResponse, topY: CGFloat) -> CGFloat {
        var y = topY
        let nameFont = UIFont.systemFont(ofSize: 20, weight: .bold)
        let nameAttrs: [NSAttributedString.Key: Any] = [
            .font: nameFont,
            .foregroundColor: textPrimary
        ]
        let detailFont = UIFont.systemFont(ofSize: 18)
        let detailAttrs: [NSAttributedString.Key: Any] = [
            .font: detailFont,
            .foregroundColor: textSecondary
        ]
        let maxW = cardWidth - padH * 2

        for workout in plan.workouts.prefix(5) {
            let dayName = dayLabel(workout.day)
            let line1 = "\(dayName)  \(workout.title)" as NSString
            let lines1 = wrapText(line1 as String, font: nameFont, maxWidth: maxW)
            for ln in lines1 {
                let ns = ln as NSString
                let nsSize = ns.size(withAttributes: nameAttrs)
                ns.draw(in: CGRect(x: padH, y: y, width: nsSize.width, height: nsSize.height),
                         withAttributes: nameAttrs)
                y += 32
            }

            // Category + intensity
            let catStr = "\(workout.category) · \(workout.intensity)" as NSString
            let catSize = catStr.size(withAttributes: detailAttrs)
            catStr.draw(in: CGRect(x: padH + 16, y: y, width: catSize.width, height: catSize.height),
                         withAttributes: detailAttrs)
            y += 28

            // Distance / Duration
            var extras: [String] = []
            if let dist = workout.distanceKm { extras.append("\(dist) km") }
            if let dur = workout.durationMinutes { extras.append("\(dur) min") }
            if !extras.isEmpty {
                let extraStr = (extras.joined(separator: "  ·  ") as NSString)
                let extraSize = extraStr.size(withAttributes: detailAttrs)
                extraStr.draw(in: CGRect(x: padH + 16, y: y, width: extraSize.width, height: extraSize.height),
                               withAttributes: detailAttrs)
                y += 28
            }
            y += 8
        }

        return y
    }

    // MARK: - Mini Trend Chart

    private static func drawMiniTrendChart(_ c: CGContext, data: [Float], topY: CGFloat) -> CGFloat {
        let chartW = cardWidth - padH * 2
        let chartH: CGFloat = 120
        let chartTop = topY + 12
        let chartBottom = chartTop + chartH

        // Card background
        let cardRect = CGRect(x: padH, y: chartTop, width: chartW, height: chartH)
        let cardPath = UIBezierPath(roundedRect: cardRect, cornerRadius: 20)
        c.setFillColor(cardSurface.cgColor)
        c.addPath(cardPath.cgPath)
        c.fillPath()

        // Line chart path
        let stepX = chartW / CGFloat(max(data.count - 1, 1))
        let linePath = UIBezierPath()

        for (i, value) in data.enumerated() {
            let x = padH + stepX * CGFloat(i)
            let clamped = max(0, min(1, value))
            let y = chartBottom - (CGFloat(clamped) * (chartH - 20)) - 10
            if i == 0 {
                linePath.move(to: CGPoint(x: x, y: y))
            } else {
                linePath.addLine(to: CGPoint(x: x, y: y))
            }
        }

        c.setStrokeColor(mint.cgColor)
        c.setLineWidth(4)
        c.setLineCap(.round)
        c.setLineJoin(.round)
        c.addPath(linePath.cgPath)
        c.strokePath()

        // Fill under line
        let fillPath = UIBezierPath(cgPath: linePath.cgPath)
        fillPath.addLine(to: CGPoint(x: padH + stepX * CGFloat(data.count - 1), y: chartBottom))
        fillPath.addLine(to: CGPoint(x: padH, y: chartBottom))
        fillPath.close()
        c.setFillColor(mint.withAlphaComponent(0.12).cgColor)
        c.addPath(fillPath.cgPath)
        c.fillPath()

        return chartBottom + 24
    }

    // MARK: - Footer

    private static func drawFooter(_ c: CGContext) {
        let divY = cardHeight - 100
        c.setStrokeColor(divider.cgColor)
        c.setLineWidth(1)
        c.move(to: CGPoint(x: padH, y: divY))
        c.addLine(to: CGPoint(x: cardWidth - padH, y: divY))
        c.strokePath()

        let font = UIFont.systemFont(ofSize: 18)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textMuted
        ]
        let footerText = "Generated by RunForm Injury Prevention Coach  ·  runform.coach" as NSString
        let size = footerText.size(withAttributes: attrs)
        footerText.draw(at: CGPoint(x: (cardWidth - size.width) / 2, y: divY + 44),
                         withAttributes: attrs)
    }

    // MARK: - Utilities

    /// Simple word-wrap helper (mirrors Android wrapText).
    private static func wrapText(_ text: String, font: UIFont, maxWidth: CGFloat) -> [String] {
        let words = text.split(separator: " ")
        var lines: [String] = []
        var currentLine = ""
        for word in words {
            let testLine = currentLine.isEmpty ? String(word) : "\(currentLine) \(word)"
            let nsTest = testLine as NSString
            let testSize = nsTest.size(withAttributes: [.font: font])
            if testSize.width <= maxWidth {
                if !currentLine.isEmpty { currentLine += " " }
                currentLine += word
            } else {
                if !currentLine.isEmpty {
                    lines.append(currentLine)
                }
                currentLine = String(word)
            }
        }
        if !currentLine.isEmpty {
            lines.append(currentLine)
        }
        return lines.isEmpty ? [text] : lines
    }

    private static func dayLabel(_ day: String) -> String {
        switch day.lowercased().prefix(3) {
        case "mon": return "Mon"
        case "tue": return "Tue"
        case "wed": return "Wed"
        case "thu": return "Thu"
        case "fri": return "Fri"
        case "sat": return "Sat"
        case "sun": return "Sun"
        default: return day
        }
    }
}
