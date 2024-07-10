class TrainingSettings {
  final int speed;   // 0-100
  final int spin;    // -50 to +50
  final int freq;    // 0-100
  final int width;   // 0-100
  final int height;  // 0-100
  final int net;     // 0-100
  final int delay;   // 0-100

  TrainingSettings({
    required this.speed,
    required this.spin,
    required this.freq,
    required this.width,
    required this.height,
    required this.net,
    required this.delay,
  });

  Map<String, dynamic> toJson() {
    return {
      'speed': speed,
      'spin': spin,
      'freq': freq,
      'width': width,
      'height': height,
      'net': net,
      'delay': delay,
    };
  }

  factory TrainingSettings.fromJson(Map<String, dynamic> json) {
    return TrainingSettings(
      speed: json['speed'],
      spin: json['spin'],
      freq: json['freq'],
      width: json['width'],
      height: json['height'],
      net: json['net'],
      delay: json['delay'],
    );
  }
}
