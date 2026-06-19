import 'dart:math';

class QLearningModel {
  // States: Location + Weather + CampusStatus
  // Actions: Stay, Move

  final double _explorationRate = 0.2; // Epsilon

  QLearningModel() {
    _initializeQTable();
  }

  void _initializeQTable() {
    // Mock initialization for prototype
    // In real app, load from SharedPrefs
  }

  String getRecommendation(String currentState) {
    if (Random().nextDouble() < _explorationRate) {
      // Explore: Random action
      return Random().nextBool() ? "Tetap Disini" : "Pindah Lokasi";
    } else {
      // Exploit: Best action
      // For prototype, return simplified logic based on state
      if (currentState.contains("Hujan")) return "Berteduh / Pindah ke Teras";
      if (currentState.contains("Sepi")) return "Pindah Lokasi";
      return "Tetap Disini (Prospek Bagus)";
    }
  }

  void updateQValue(String state, String action, double reward, String nextState) {
    // Q(s,a) = Q(s,a) + alpha * [r + gamma * maxQ(s',a') - Q(s,a)]
    // Placeholder implementation
  }
}
