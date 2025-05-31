import 'package:flutter/material.dart';
import 'package:myportfolio/main_page/scroll_column/section_wrapper.dart';

class AboutSection extends StatefulWidget {
  const AboutSection({super.key});

  @override
  AboutSectionState createState() => AboutSectionState();
}

class AboutSectionState extends State<AboutSection> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SectionWrapper(
      child: buildRichText(theme),
    );
  }

  /// Helper method to construct the [Text.rich] widget.
  Widget buildRichText(ThemeData theme) {
    return Text.rich(
      TextSpan(
        children: [
          buildText(theme, "Professional Summary\n\n", FontWeight.bold),
          buildText(
            theme,
            "Results-driven DevOps Engineer with hands-on experience in cloud infrastructure automation and integration development. "
            "Specialized in designing, implementing, and maintaining scalable systems across Oracle Cloud Infrastructure (OCI) and Microsoft Azure environments. "
            "Proven track record of optimizing deployment pipelines, reducing manual intervention, and implementing robust automation frameworks. "
            "Driven by solving complex infrastructure challenges and accelerating delivery cycles while maintaining system reliability and security.\n\n",
            FontWeight.w400,
          ),
          buildText(theme, "Core Expertise\n\n", FontWeight.bold),
          buildText(
            theme,
            "Infrastructure as Code, CI/CD Automation, Cloud Architecture, Configuration Management\n\n",
            FontWeight.w400,
          ),
          buildText(theme, "Passion\n\n", FontWeight.bold),
          buildText(
            theme,
            "Refactoring and improving code/infrastructure",
            FontWeight.w400,
          ),
        ],
      ),
    );
  }

  /// Creates a [TextSpan] with shadow effects and customizable font weight.
  TextSpan buildText(ThemeData theme, String text, FontWeight fontWeight) {
    return TextSpan(
      text: text,
      style: theme.textTheme.bodyMedium?.copyWith(
        fontWeight: fontWeight,
        shadows: [
          Shadow(
            blurRadius: 2,
            color: Colors.black.withOpacity(0.3),
            offset: const Offset(2.0, 2.0),
          ),
        ],
      ),
    );
  }
}