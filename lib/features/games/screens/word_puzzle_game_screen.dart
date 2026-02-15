import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/extensions/theme_extension.dart';
import '../../../data/providers/game_provider.dart';

class EyeQuestGameScreen extends StatefulWidget {
  const EyeQuestGameScreen({super.key});

  @override
  State<EyeQuestGameScreen> createState() => _EyeQuestGameScreenState();
}

class _EyeQuestGameScreenState extends State<EyeQuestGameScreen> {
  final List<Map<String, String>> _allWordData = [
    {'word': 'PUPIL', 'hint': 'Center of the iris.'},
    {'word': 'IRIS', 'hint': 'Colored part of the eye.'},
    {'word': 'CORNEA', 'hint': 'Clear front surface.'},
    {'word': 'RETINA', 'hint': 'Light-sensitive layer.'},
    {'word': 'SCLERA', 'hint': 'White outer layer.'},
    {'word': 'LENS', 'hint': 'Focusing structure.'},
    {'word': 'OPTIC', 'hint': 'Relating to vision.'},
    {'word': 'MACULA', 'hint': 'Central vision area.'},
    {'word': 'VISION', 'hint': 'Ability to see.'},
    {'word': 'ACUITY', 'hint': 'Sharpness of vision.'},
    {'word': 'MYOPIA', 'hint': 'Nearsightedness.'},
    {'word': 'FOVEA', 'hint': 'Pit for sharpest vision.'},
    {'word': 'EYELID', 'hint': 'Protective eye cover.'},
    {'word': 'TEARS', 'hint': 'Lubricating fluid.'},
    {'word': 'BLINK', 'hint': 'Quick eye closure.'},
    {'word': 'GLARE', 'hint': 'Harsh bright light.'},
    {'word': 'FOCUS', 'hint': 'Clear image point.'},
    {'word': 'CONES', 'hint': 'Color sensing cells.'},
    {'word': 'RODS', 'hint': 'Low light sensing cells.'},
    {'word': 'LASER', 'hint': 'Surgical light beam.'},
    {'word': 'GLASSES', 'hint': 'Vision correction frames.'},
    {'word': 'FRAMES', 'hint': 'Eyewear structure.'},
    {'word': 'PRISM', 'hint': 'Triangular glass optic.'},
    {'word': 'STIGMA', 'hint': 'Related to Astigmatism.'},
    {'word': 'CATARACT', 'hint': 'Cloudy eye lens.'},
    {'word': 'GLAUCOMA', 'hint': 'High eye pressure.'},
    {'word': 'UVEITIS', 'hint': 'Inner eye inflammation.'},
    {'word': 'DIPLOPIA', 'hint': 'Double vision.'},
    {'word': 'STRABIS', 'hint': 'Misaligned eyes.'},
    {'word': 'ORBIT', 'hint': 'Eye socket.'},
    {'word': 'NERVE', 'hint': 'Sends signals to brain.'},
    {'word': 'FUNDUS', 'hint': 'Interior eye surface.'},
    {'word': 'CHART', 'hint': 'Snellen vision test.'},
    {'word': 'SNELLEN', 'hint': 'Famous vision chart.'},
    {'word': 'DIOPTER', 'hint': 'Lens power unit.'},
    {'word': 'SPHERE', 'hint': 'Basic lens power.'},
    {'word': 'AXIS', 'hint': 'Astigmatism angle.'},
    {'word': 'VITREOUS', 'hint': 'Gel inside the eye.'},
    {'word': 'AQUEOUS', 'hint': 'Fluid in front of lens.'},
    {'word': 'CHOROID', 'hint': 'Eye vascular layer.'},
    {'word': 'EYELASH', 'hint': 'Lid hair protection.'},
    {'word': 'PTOSIS', 'hint': 'Drooping eyelid.'},
    {'word': 'LASIK', 'hint': 'Vision correction surgery.'},
    {'word': 'SMILE', 'hint': 'Newer laser surgery.'},
    {'word': 'HYPHEMA', 'hint': 'Blood in front chamber.'},
    {'word': 'KERATIT', 'hint': 'Cornea inflammation.'},
    {'word': 'IRITIS', 'hint': 'Iris inflammation.'},
    {'word': 'ARCUS', 'hint': 'White corneal ring.'},
    {'word': 'CHALAZI', 'hint': 'Eyelid lump/cyst.'},
    {'word': 'BLEPHAR', 'hint': 'Eyelid related.'},
    {'word': 'EYEWEAR', 'hint': 'Glasses and contacts.'},
    {'word': 'MYOPE', 'hint': 'Person with myopia.'},
    {'word': 'BRIGHT', 'hint': 'Opposite of dim.'},
    {'word': 'REFRACT', 'hint': 'Bending of light.'},
    {'word': 'IMAGE', 'hint': 'What the retina sees.'},
    {'word': 'NODAL', 'hint': 'Optical center point.'},
    {'word': 'PUNCTA', 'hint': 'Tear drainage hole.'},
    {'word': 'LIMBUS', 'hint': 'Cornea-sclera border.'},
    {'word': 'STROMA', 'hint': 'Thick corneal layer.'},
    {'word': 'CANTHUS', 'hint': 'Corner of the eye.'},
    {'word': 'ZONULES', 'hint': 'Lens holding fibers.'},
    {'word': 'TUNICA', 'hint': 'Anatomical eye layer.'},
    {'word': 'VESSEL', 'hint': 'Retinal blood carrier.'},
    {'word': 'OBLIQUE', 'hint': 'Extraocular muscle.'},
    {'word': 'RECTUS', 'hint': 'Straight eye muscle.'},
    {'word': 'CILIARY', 'hint': 'Lens focusing muscle.'},
    {'word': 'MANTLE', 'hint': 'Protective layer.'},
    {'word': 'CHAMBER', 'hint': 'Eye fluid space.'},
    {'word': 'SIGHT', 'hint': 'Sense of vision.'},
    {'word': 'BINARY', 'hint': 'Stereoscopy related.'},
    {'word': 'DEPTH', 'hint': '3D perception.'},
    {'word': 'BLIND', 'hint': 'Lack of vision.'},
    {'word': 'BLINKER', 'hint': 'Used for eye testing.'},
    {'word': 'LUX', 'hint': 'Unit of illumination.'},
    {'word': 'CANDELA', 'hint': 'Intensity of light.'},
    {'word': 'SPEKTR', 'hint': 'Color range.'},
    {'word': 'PHOTON', 'hint': 'Particle of light.'},
    {'word': 'QUARTZ', 'hint': 'Used in high-end lenses.'},
    {'word': 'COATING', 'hint': 'Anti-glare layer.'},
    {'word': 'STRAY', 'hint': 'Unwanted light glare.'},
    {'word': 'DILATE', 'hint': 'Enlarge the pupil.'},
    {'word': 'FOCAL', 'hint': 'Relating to focus.'},
    {'word': 'PLANO', 'hint': 'Zero power lens.'},
    {'word': 'SHADE', 'hint': 'Protection from sun.'},
    {'word': 'FILTER', 'hint': 'Blocks specific light.'},
    {'word': 'POLAR', 'hint': 'Light wave direction.'},
    {'word': 'TINTED', 'hint': 'Colored lenses.'},
    {'word': 'AMBER', 'hint': 'Common lens tint.'},
    {'word': 'GRADIENT', 'hint': 'Varying lens tint.'},
    {'word': 'ABBE', 'hint': 'Optical value term.'},
    {'word': 'MIRROR', 'hint': 'Reflective lens finish.'},
    {'word': 'SPORT', 'hint': 'Protective eyewear.'},
    {'word': 'SAFETY', 'hint': 'Industrial eyewear.'},
    {'word': 'HYGIENE', 'hint': 'Contact lens care.'},
    {'word': 'SALINE', 'hint': 'Lens rinsing fluid.'},
    {'word': 'CASE', 'hint': 'Eyewear storage.'},
    {'word': 'CLOTH', 'hint': 'Microfiber cleaner.'},
    {'word': 'SOLUTION', 'hint': 'Lens cleaning liquid.'},
    {'word': 'DROP', 'hint': 'Eye medication unit.'},
    {'word': 'DRYNESS', 'hint': 'Lack of moisture.'},
  ];

  late List<Map<String, String>> _shuffledWordData;

  int _level = 1;
  late String _targetWord;
  late String _hint;
  final List<String> _guesses = [];
  String _currentGuess = "";
  final int _maxGuesses = 6;
  bool _isGameOver = false;
  bool _isWin = false;

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  void _loadProgress() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final provider = context.read<GameProvider>();
    final progress = provider.getProgress('eye_quest');

    setState(() {
      _level = progress?.currentLevel ?? 1;

      // SHUFFLE DETERMINISTICALLY PER USER
      _shuffledWordData = List.from(_allWordData);
      // Use UserID hashCode as seed
      final seed = user.uid.hashCode;
      _shuffledWordData.shuffle(math.Random(seed));

      _initLevel();
    });
  }

  void _initLevel() {
    final data = _shuffledWordData[(_level - 1) % _shuffledWordData.length];
    _targetWord = data['word']!.toUpperCase();
    _hint = data['hint']!;
    _guesses.clear();
    _currentGuess = "";
    _isGameOver = false;
    _isWin = false;
  }

  void _onKeyTap(String key) {
    if (_isGameOver) return;

    setState(() {
      if (key == 'DEL') {
        if (_currentGuess.isNotEmpty) {
          _currentGuess = _currentGuess.substring(0, _currentGuess.length - 1);
        }
      } else if (key == 'ENTER') {
        if (_currentGuess.length == _targetWord.length) {
          _submitGuess();
        }
      } else {
        if (_currentGuess.length < _targetWord.length) {
          _currentGuess += key;
        }
      }
    });
  }

  void _submitGuess() {
    _guesses.add(_currentGuess);
    if (_currentGuess == _targetWord) {
      _isWin = true;
      _isGameOver = true;
      _saveProgress();
    } else if (_guesses.length >= _maxGuesses) {
      _isGameOver = true;
    }
    _currentGuess = "";
    HapticFeedback.mediumImpact();
  }

  void _saveProgress() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final role = AuthService().cachedUser?.role.name ?? 'user';
      context.read<GameProvider>().clearLevel(
        user.uid,
        'eye_quest',
        _level,
        100, // Fixed score for puzzle
        userName: user.displayName ?? 'Player',
        userRole: role,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop && !_isGameOver) _saveProgress();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Background
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    context.primary.withValues(alpha: 0.1),
                    Colors.black,
                    Colors.black,
                  ],
                ),
              ),
            ),

            SafeArea(
              child: Column(
                children: [
                  _buildHeader(),
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [_buildHint(), _buildGrid()],
                        ),
                      ),
                    ),
                  ),
                  _buildKeyboard(),
                  const SizedBox(height: 16),
                ],
              ),
            ),

            if (_isGameOver) _buildOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          Column(
            children: [
              const Text(
                'EYE QUEST',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                ),
              ),
              Text(
                'LEVEL $_level',
                style: TextStyle(
                  color: context.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(width: 48), // Spacer
        ],
      ),
    );
  }

  Widget _buildHint() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lightbulb_outline_rounded,
                color: context.primary,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                'HINT',
                style: TextStyle(
                  color: context.primary,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _hint,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double availableWidth = constraints.maxWidth - 48;
        final double boxSize = (availableWidth / _targetWord.length).clamp(
          35.0,
          50.0,
        );

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(_maxGuesses, (rowIndex) {
              String word = "";
              if (rowIndex < _guesses.length) {
                word = _guesses[rowIndex];
              } else if (rowIndex == _guesses.length && !_isGameOver) {
                word = _currentGuess;
              }

              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_targetWord.length, (colIndex) {
                  String char = "";
                  if (colIndex < word.length) char = word[colIndex];

                  Color bgColor = Colors.transparent;
                  Color borderColor = Colors.white24;

                  if (rowIndex < _guesses.length) {
                    if (_targetWord[colIndex] == char) {
                      bgColor = Colors.green.withValues(alpha: 0.6);
                      borderColor = Colors.green;
                    } else if (_targetWord.contains(char)) {
                      bgColor = Colors.amber.withValues(alpha: 0.6);
                      borderColor = Colors.amber;
                    } else {
                      bgColor = Colors.white.withValues(alpha: 0.1);
                      borderColor = Colors.white12;
                    }
                  } else if (rowIndex == _guesses.length &&
                      colIndex < _currentGuess.length) {
                    borderColor = context.primary;
                  }

                  return AnimatedContainer(
                        duration: 300.ms,
                        margin: const EdgeInsets.all(3),
                        width: boxSize,
                        height: boxSize,
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: borderColor, width: 2),
                        ),
                        child: Center(
                          child: Text(
                            char,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: boxSize * 0.45,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      )
                      .animate(target: char.isNotEmpty ? 1 : 0)
                      .shake(duration: 200.ms);
                }),
              );
            }),
          ),
        );
      },
    );
  }

  Widget _buildKeyboard() {
    const keys = [
      ['Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P'],
      ['A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L'],
      ['DEL', 'Z', 'X', 'C', 'V', 'B', 'N', 'M', 'ENTER'],
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final double keyWidth = (constraints.maxWidth - 60) / 10;

        return Column(
          children: keys.map((row) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: row.map((key) {
                final isDel = key == 'DEL';
                final isEnter = key == 'ENTER';
                final isSpecial = isDel || isEnter;

                return GestureDetector(
                  onTap: () => _onKeyTap(key),
                  child: Container(
                    margin: const EdgeInsets.all(2),
                    width: isSpecial ? keyWidth * 1.5 : keyWidth,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: isDel
                          ? const Icon(
                              Icons.backspace_outlined,
                              color: Colors.white,
                              size: 20,
                            )
                          : Text(
                              key,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isSpecial ? 10 : 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                );
              }).toList(),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.85),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: context.cardColor,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: (_isWin ? Colors.green : Colors.red).withValues(
                alpha: 0.5,
              ),
              width: 2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _isWin
                    ? Icons.stars_rounded
                    : Icons.sentiment_dissatisfied_rounded,
                color: _isWin ? Colors.amber : Colors.redAccent,
                size: 80,
              ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
              const SizedBox(height: 24),
              Text(
                _isWin ? 'EXCELLENT!' : 'GAME OVER',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _isWin
                    ? 'You identified the concept!'
                    : 'Better luck next time!',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Text(
                      'CONCEPT',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _targetWord,
                      style: TextStyle(
                        color: _isWin ? Colors.green : Colors.redAccent,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  if (_isWin) {
                    setState(() {
                      _level++;
                      _initLevel();
                    });
                  } else {
                    setState(() {
                      _initLevel();
                    });
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isWin ? Colors.green : context.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 48,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  _isWin ? 'NEXT LEVEL' : 'TRY AGAIN',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              if (!_isWin)
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'EXIT',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
