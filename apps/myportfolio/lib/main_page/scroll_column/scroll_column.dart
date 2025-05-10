import 'package:flutter/material.dart';
import 'package:myportfolio/main_page/scroll_column/experience_section/experience_section.dart';
import 'package:myportfolio/main_page/scroll_column/experience_section/buttons/resume_button.dart';
import 'package:myportfolio/main_page/scroll_column/project_section/project_section.dart';
import 'package:myportfolio/main_page/scroll_column/about_section/about_section.dart';
import 'package:myportfolio/main_page/scroll_column/footer_section/footer_section.dart';

class ScrollColumn extends StatelessWidget {
  final GlobalKey experienceKey;
  final GlobalKey projectsKey;

  const ScrollColumn({
    super.key,
    required this.experienceKey,
    required this.projectsKey,
  }); 

  @override
  Widget build(BuildContext context) {
   
    final List<Widget> columnChildren = [
      const SizedBox(height: 145),
      const AboutSection(),
      const SizedBox(height: 100),
      // Experience Section with key
      Container(key: experienceKey, child: const ExperienceSection()),
      const ResumeButton(),
      const SizedBox(height: 100),
      // Projects Section with key
      Container(key: projectsKey, child: const ProjectSection()),
      const SizedBox(height: 100),
      const FooterSection(),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.start,
      children: columnChildren,
    );
  }
}
