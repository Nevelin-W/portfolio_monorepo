import 'package:flutter/material.dart';
import 'package:myportfolio/main_page/scroll_column/experience_section/experience_item.dart';

class ExperienceSection extends StatelessWidget {
  const ExperienceSection({super.key});

  @override
  Widget build(BuildContext context) {
    final List<ExperienceItem> experiences = [
      const ExperienceItem(
        startDate: '04/2024',
        endDate: 'Present',
        title: 'DevOps Engineer — Accenture Baltics',
        description: '''
• Manage DevOps operations across Oracle Cloud Infrastructure (OCI) and Microsoft Azure.
• Design and maintain CI/CD pipelines for deployments, provisioning, and artifact packaging.
• Implement IaC using Terraform (OCI) and Bicep (Azure) to maintain consistent environments.
• Migrate legacy infrastructure to modern solutions, enhancing maintainability and efficiency.
• Develop custom monitoring and alerting solutions.
• Collaborate with developers to streamline pipelines and enforce best practices.
''',
        techList: [
          'Terraform', 'Bicep', 'CI/CD', 'OCI', 'Azure', 'Linux', 'Python', 'Shell Scripting', 'Docker', 'GitHub Actions', 'Azure DevOps'
        ],
      ),
      const ExperienceItem(
        startDate: '04/2022',
        endDate: '04/2024',
        title: 'Cloud Integration Developer — Accenture Baltics',
        description: '''
• Progressed from Intern to Junior Developer to Integration Developer over two years.
• Built and maintained API integrations using MuleSoft for enterprise and ad automation systems.
• Contributed to data migration and automation workflows across client projects.
• Developed foundational skills in integration logic, agile teamwork, and cloud platforms.
''',
        techList: [
          'MuleSoft', 'Dataweave', 'JSON', 'XML', 'MUnit', 'API Integration', 'OCI', 'Azure'
        ],
      ),
    ];

    return Column(
      children: experiences
          .map((experience) => Padding(
                padding: const EdgeInsets.only(bottom: 10.0),
                child: experience,
              ))
          .toList(),
    );
  }
}