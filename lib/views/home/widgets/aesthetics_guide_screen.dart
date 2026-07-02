import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';

class AestheticsGuideScreen extends StatelessWidget {
  const AestheticsGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Qoves Aesthetics Guide"),
        backgroundColor: AppColors.cardBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header description
            const Text(
              "FACIAL GEOMETRY & PROPORTIONS",
              style: TextStyle(
                color: AppColors.primaryGold,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Understand the scientific metrics behind facial assessment, symmetry, and bone structure alignment.",
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 24),

            // Simulated wireframe face diagram
            Container(
              height: 220,
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              padding: const EdgeInsets.all(16),
              child: CustomPaint(
                painter: FacialLandmarksPainter(),
                child: Container(),
              ),
            ),
            const SizedBox(height: 24),

            // Guide Cards Grid
            _buildGuideCard(
              title: "1. Vertical Facial Thirds",
              metric: "Ideal Ratio: 1 : 1 : 1",
              description: "Splits the face vertically into three equal thirds:\n"
                  "• Upper Third: Hairline (Trichion) to Mid-brows (Glabella)\n"
                  "• Middle Third: Mid-brows to Nose Base (Subnasale)\n"
                  "• Lower Third: Nose Base to Chin (Menton)\n\n"
                  "Proportional balance between these segments is a key indicator of vertical facial harmony.",
              icon: Icons.splitscreen_outlined,
            ),
            const SizedBox(height: 16),

            _buildGuideCard(
              title: "2. Mandibular Gonial Angle",
              metric: "Ideal Angle: 120° - 130°",
              description: "The angle formed by the back vertical edge (ramus) and the lower horizontal edge of the jawbone.\n"
                  "• A smaller angle (110°-115°) creates a highly defined, square jawline.\n"
                  "• A wider angle (135°+) creates a softer, more tapered slope.\n"
                  "Symmetry between the left and right gonial slopes defines a balanced jaw profile.",
              icon: Icons.architecture,
            ),
            const SizedBox(height: 16),

            _buildGuideCard(
              title: "3. Bilateral Facial Symmetry",
              metric: "Optimal Range: 90% - 98%",
              description: "Measures structural differences between the left and right sides of the sagittal facial axis.\n"
                  "While slight asymmetry is natural and universal, high bilateral symmetry represents stable developmental aesthetics and balanced muscular toning.",
              icon: Icons.contrast,
            ),
            const SizedBox(height: 16),

            _buildGuideCard(
              title: "4. Zygomatic Arch (Cheekbones)",
              metric: "Prominence Ratio",
              description: "The lateral width of the cheekbones compared to the width of the lower jaw. Strong zygomatic arch definition provides mid-face support, lifting the skin and preventing nasolabial sagging over time.",
              icon: Icons.visibility_outlined,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildGuideCard({
    required String title,
    required String metric,
    required String description,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primaryGold, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.primaryGold.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              metric,
              style: const TextStyle(
                color: AppColors.primaryGold,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class FacialLandmarksPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final paintLine = Paint()
      ..color = AppColors.primaryGold.withValues(alpha: 0.3)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;


    final paintDot = Paint()
      ..color = AppColors.primaryGold
      ..style = PaintingStyle.fill;

    // Define coordinates representing a premium front-facing wireframe face
    final Offset trichion = Offset(w * 0.5, h * 0.1);
    final Offset glabella = Offset(w * 0.5, h * 0.35);
    final Offset subnasale = Offset(w * 0.5, h * 0.6);
    final Offset menton = Offset(w * 0.5, h * 0.9);

    final Offset eyeLeft = Offset(w * 0.38, h * 0.42);
    final Offset eyeRight = Offset(w * 0.62, h * 0.42);

    final Offset cheekLeft = Offset(w * 0.28, h * 0.55);
    final Offset cheekRight = Offset(w * 0.72, h * 0.55);

    final Offset jawLeft = Offset(w * 0.32, h * 0.76);
    final Offset jawRight = Offset(w * 0.68, h * 0.76);

    // 1. Draw Sagittal Midline
    canvas.drawLine(trichion, menton, paintLine);

    // 2. Draw Horizontal Thirds lines
    canvas.drawLine(Offset(w * 0.2, glabella.dy), Offset(w * 0.8, glabella.dy), paintLine);
    canvas.drawLine(Offset(w * 0.2, subnasale.dy), Offset(w * 0.8, subnasale.dy), paintLine);

    // 3. Draw outer structural wireframe
    final Path facePath = Path()
      ..moveTo(trichion.dx, trichion.dy)
      ..quadraticBezierTo(w * 0.32, h * 0.2, cheekLeft.dx, cheekLeft.dy)
      ..lineTo(jawLeft.dx, jawLeft.dy)
      ..lineTo(menton.dx, menton.dy)
      ..lineTo(jawRight.dx, jawRight.dy)
      ..lineTo(cheekRight.dx, cheekRight.dy)
      ..quadraticBezierTo(w * 0.68, h * 0.2, trichion.dx, trichion.dy);
    canvas.drawPath(facePath, paintLine);

    // 4. Draw eyes alignment & cheeks line
    canvas.drawLine(eyeLeft, eyeRight, paintLine);
    canvas.drawLine(cheekLeft, cheekRight, paintLine);
    canvas.drawLine(jawLeft, jawRight, paintLine);

    // Connecting guides
    canvas.drawLine(eyeLeft, subnasale, paintLine);
    canvas.drawLine(eyeRight, subnasale, paintLine);
    canvas.drawLine(subnasale, jawLeft, paintLine);
    canvas.drawLine(subnasale, jawRight, paintLine);

    // 5. Draw highlighted golden dots
    final List<Offset> dots = [
      trichion, glabella, subnasale, menton,
      eyeLeft, eyeRight,
      cheekLeft, cheekRight,
      jawLeft, jawRight
    ];

    for (final dot in dots) {
      canvas.drawCircle(dot, 4.0, paintDot);
      canvas.drawCircle(dot, 7.0, Paint()
        ..color = AppColors.primaryGold.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
      );
    }

    // Label the vertical thirds on the side
    const textStyle = TextStyle(color: AppColors.primaryGold, fontSize: 9, fontWeight: FontWeight.bold);
    
    _drawText(canvas, "UPPER THIRD", Offset(w * 0.82, (trichion.dy + glabella.dy) / 2 - 5), textStyle);
    _drawText(canvas, "MIDDLE THIRD", Offset(w * 0.82, (glabella.dy + subnasale.dy) / 2 - 5), textStyle);
    _drawText(canvas, "LOWER THIRD", Offset(w * 0.82, (subnasale.dy + menton.dy) / 2 - 5), textStyle);
  }

  void _drawText(Canvas canvas, String text, Offset offset, TextStyle style) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
