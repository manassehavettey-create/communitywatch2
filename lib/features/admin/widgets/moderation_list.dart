import 'package:flutter/material.dart';

class ModerationList extends StatelessWidget {
  const ModerationList({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 3,
      separatorBuilder: (context, index) => const Divider(),
      itemBuilder: (context, index) {
        return ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            'Report #89${index + 1} - ${_getReportType(index)}',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          subtitle: Text('Flagged by ${index + 2} users • ${index + 1}h ago'),
          trailing: Wrap(
            spacing: 0,
            children: [
              IconButton(
                icon: const Icon(Icons.check_circle_outline, color: Colors.green),
                tooltip: 'Approve',
                onPressed: () {},
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                tooltip: 'Reject',
                onPressed: () {},
              ),
            ],
          ),
        );
      },
    );
  }

  String _getReportType(int index) {
    const types = ['Suspicious Activity', 'Theft', 'Vandalism'];
    return types[index % types.length];
  }
}
