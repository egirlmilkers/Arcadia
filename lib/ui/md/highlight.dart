import 'package:flutter/material.dart';

class Highlight extends StatelessWidget {
  final String text;

  const Highlight({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      transform: Matrix4.translationValues(0, -2, 0),
      padding: EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(
        text,
        style: TextStyle(fontFamily: 'GoogleSansCode', color: Colors.grey[200]),
      ),
    );
  }
}
