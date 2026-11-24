import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Flat duotone marks for Home tiles. Files live in assets/illustrations.
class HomeIllustration extends StatelessWidget {
  const HomeIllustration(this.name, {super.key, this.size = 40});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/illustrations/$name.svg',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}

String languageIllustration(String english) => 'lang_${english.toLowerCase()}';
