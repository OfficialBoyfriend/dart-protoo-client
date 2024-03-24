import 'dart:math';

int min = 0;
int max = 10000000;

int get randomNumber => min + Random().nextInt(max - min);
