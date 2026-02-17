import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/extensions/theme_extension.dart';
import '../../../data/providers/game_provider.dart';
import '../../../core/services/audio_service.dart';
import '../widgets/game_menus.dart';

class EyeQuestGameScreen extends StatefulWidget {
  const EyeQuestGameScreen({super.key});

  @override
  State<EyeQuestGameScreen> createState() => _EyeQuestGameScreenState();
}

class _EyeQuestGameScreenState extends State<EyeQuestGameScreen> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _loadProgress();
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  final List<Map<String, String>> _allWordData = [
    // --- TIER 1: FAMILIAR TERMS (Levels 1-30) ---
    {
      'word': 'PUPIL',
      'hint': 'The dark center of your eye.',
      'details': 'Opening in the center of the iris that controls light entry.',
    },
    {
      'word': 'IRIS',
      'hint': 'The colored part of the eye.',
      'details':
          'The circular structure containing muscle that controls pupil size.',
    },
    {
      'word': 'LENS',
      'hint': 'Helps you focus on objects.',
      'details':
          'Transparent structure behind the pupil that focuses light on the retina.',
    },
    {
      'word': 'VISION',
      'hint': 'The faculty of seeing.',
      'details':
          'The process of light becoming neural signals for brain processing.',
    },
    {
      'word': 'EYELID',
      'hint': 'Skin that covers your eye.',
      'details':
          'Thin fold of skin that protects and spreads tears over the eye.',
    },
    {
      'word': 'TEARS',
      'hint': 'Fluid that cleans the eye.',
      'details':
          'Watery liquid produced by lacrimal glands to lubricate the surface.',
    },
    {
      'word': 'BLINK',
      'hint': 'Quick closing of the lids.',
      'details': 'Reflex action that protects and cleans the ocular surface.',
    },
    {
      'word': 'SIGHT',
      'hint': 'A primary human sense.',
      'details':
          'The ability to perceive visual information from the environment.',
    },
    {
      'word': 'EYE',
      'hint': 'The organ used for seeing.',
      'details':
          'The sensory organ located in the bony socket (orbit) of the skull.',
    },
    {
      'word': 'CHART',
      'hint': 'Used during a vision test.',
      'details': 'A tool like the Snellen chart used to measure visual acuity.',
    },
    {
      'word': 'FOCUS',
      'hint': 'Making an image clear.',
      'details': 'The point where light rays converge to create a sharp image.',
    },
    {
      'word': 'ACUITY',
      'hint': 'Sharpness of your vision.',
      'details':
          'Ability to distinguish fine details, often measured as 20/20.',
    },
    {
      'word': 'CORNEA',
      'hint': 'Clear front window of eye.',
      'details':
          'The transparent outer layer that provides most focusing power.',
    },
    {
      'word': 'RETINA',
      'hint': 'Light sensing back tissue.',
      'details':
          'Inner lining of the eye that converts light into electrical signals.',
    },
    {
      'word': 'MACULA',
      'hint': 'Center of sharp vision.',
      'details': 'Part of the retina responsible for detailed, central vision.',
    },
    {
      'word': 'SCLERA',
      'hint': 'The white part of the eye.',
      'details': 'Tough outer wall of the eyeball that maintains its shape.',
    },
    {
      'word': 'MYOPIA',
      'hint': 'Term for nearsightedness.',
      'details': 'Vision condition where distant objects appear blurred.',
    },
    {
      'word': 'CONES',
      'hint': 'Cells for color vision.',
      'details':
          'Photoreceptors in the macula responsible for color and detail.',
    },
    {
      'word': 'RODS',
      'hint': 'Cells for low-light vision.',
      'details':
          'Photoreceptors in peripheral retina for night and motion sensing.',
    },
    {
      'word': 'NERVE',
      'hint': 'Carrier of visual signals.',
      'details': 'The optic nerve connects the retina directly to the brain.',
    },
    {
      'word': 'ORBIT',
      'hint': 'Socket for the eyeball.',
      'details':
          'The bony cavity in the skull that holds and protects the eye.',
    },
    {
      'word': 'BLURRY',
      'hint': 'When things look unclear.',
      'details': 'Visual distortion caused by improper focusing of light.',
    },
    {
      'word': 'BRIGHT',
      'hint': 'Opposite of a dim room.',
      'details': 'Luminous environment requiring constriction of the pupil.',
    },
    {
      'word': 'GLASS',
      'hint': 'Traditional lens material.',
      'details': 'Optical material used in eyeglasses for correcting vision.',
    },
    {
      'word': 'LIGHTS',
      'hint': 'What the eyes perceive.',
      'details': 'Electromagnetic radiation detected by the sensory retina.',
    },
    {
      'word': 'GLARE',
      'hint': 'Brightness that bothers.',
      'details': 'Visual interference caused by unwanted light reflections.',
    },
    {
      'word': 'DEPTH',
      'hint': 'Seeing three dimensions.',
      'details': 'Binocular perception that allows us to judge distances.',
    },
    {
      'word': 'LOOK',
      'hint': 'To direct your gaze.',
      'details': 'Active focusing on a specific object in the visual field.',
    },
    {
      'word': 'WATCH',
      'hint': 'To observe over time.',
      'details': 'Following a moving image or event with visual tracking.',
    },
    {
      'word': 'SEE',
      'hint': 'To perceive with eyes.',
      'details': 'The act of sensory perception through the visual system.',
    },

    // --- TIER 2: ADVANCED CLINICAL TERMS (Levels 31-100) ---
    {
      'word': 'OPTIC',
      'hint': 'Vision-related pathway.',
      'details': 'Relating to the eyes or the science of light and vision.',
    },
    {
      'word': 'AXIS',
      'hint': 'Astigmatism orienation.',
      'details': 'The meridian in degrees used for astigmatism correction.',
    },
    {
      'word': 'PTOSIS',
      'hint': 'A drooping upper eyelid.',
      'details': 'Condition where the eyelid falls lower than normal.',
    },
    {
      'word': 'LASIK',
      'hint': 'Vision laser surgery.',
      'details': 'Refractive surgery that reshapes the cornea with a laser.',
    },
    {
      'word': 'SMILE',
      'hint': 'Advanced laser surgery.',
      'details': 'Small Incision Lenticule Extraction for myopia correction.',
    },
    {
      'word': 'IRITIS',
      'hint': 'Iris inflammation.',
      'details': 'A form of anterior uveitis affecting the colored eye part.',
    },
    {
      'word': 'ARCUS',
      'hint': 'White ring on cornea.',
      'details': 'Lipid deposit at the edge of the cornea, common with age.',
    },
    {
      'word': 'MYOPE',
      'hint': 'A nearsighted person.',
      'details': 'Someone whose eye is too long or cornea too curved.',
    },
    {
      'word': 'IMAGE',
      'hint': 'Pattern on the retina.',
      'details': 'The inverted representation formed at the back of the eye.',
    },
    {
      'word': 'NODAL',
      'hint': 'Point in eye optics.',
      'details':
          'The reference center through which light rays pass undeviated.',
    },
    {
      'word': 'PUNCTA',
      'hint': 'Tiny drainage holes.',
      'details': 'Small openings at the inner lid corner for tear exit.',
    },
    {
      'word': 'LIMBUS',
      'hint': 'Cornea-sclera border.',
      'details': 'The junction where the clear cornea meets the white sclera.',
    },
    {
      'word': 'STROMA',
      'hint': 'Thick cornea layer.',
      'details': 'The middle 90% of the cornea, providing structural strength.',
    },
    {
      'word': 'TUNICA',
      'hint': 'An eye coat layer.',
      'details': 'Anatomical term for one of the three layers of the eyeball.',
    },
    {
      'word': 'VESSEL',
      'hint': 'Carries eye blood.',
      'details': 'Artery or vein supplying nutrients to retinal tissues.',
    },
    {
      'word': 'MANTLE',
      'hint': 'Protective outer zone.',
      'details': 'Terminology for the cellular coverage of ocular structures.',
    },
    {
      'word': 'BINARY',
      'hint': 'Two-eyed vision state.',
      'details': 'Relating to the use of both eyes simultaneously (Binocular).',
    },
    {
      'word': 'BLIND',
      'hint': 'Vision is fully absent.',
      'details': 'Condition characterized by total lack of light perception.',
    },
    {
      'word': 'LUX',
      'hint': 'Illumination unit.',
      'details': 'Scientific measurement of light intensity on a surface.',
    },
    {
      'word': 'PHOTON',
      'hint': 'Unit of light energy.',
      'details': 'Elementary particle that acts as the basic unit of light.',
    },
    {
      'word': 'QUARTZ',
      'hint': 'Crystal for optics.',
      'details': 'Mineral used in manufacturing high-quality optical lenses.',
    },
    {
      'word': 'STRAY',
      'hint': 'Unwanted light rays.',
      'details': 'Light hitting internal structures away from the visual axis.',
    },
    {
      'word': 'DILATE',
      'hint': 'Pupil getting larger.',
      'details': 'Opening of the pupil, often using medicated eye drops.',
    },
    {
      'word': 'FOCAL',
      'hint': 'Related to the focus.',
      'details': 'Pertaining to the focal point or length of a lens system.',
    },
    {
      'word': 'PLANO',
      'hint': 'Zero lens power.',
      'details': 'A lens that has no magnification or refractive correction.',
    },
    {
      'word': 'SHADE',
      'hint': 'Blight light shelter.',
      'details': 'Protection intended to reduce retinal exposure to UV rays.',
    },
    {
      'word': 'FILTER',
      'hint': 'Blocks 일부 spectral.',
      'details': 'Optical device used to selectively transmit specific light.',
    },
    {
      'word': 'POLAR',
      'hint': 'Wave path alignment.',
      'details': 'Relating to polarized light used in glare-reducing lenses.',
    },
    {
      'word': 'AMBER',
      'hint': 'Warm lens coloring.',
      'details': 'Yellowish tint used to increase contrast in eyewear.',
    },
    {
      'word': 'ABBE',
      'hint': 'Dispersion value.',
      'details': 'Number describing how much a lens material spreads light.',
    },
    {
      'word': 'MIRROR',
      'hint': 'Reflective coat.',
      'details': 'Thin metallic coating applied to the outside of lenses.',
    },
    {
      'word': 'SPORT',
      'hint': 'Athletic eyewear.',
      'details': 'High-impact frames designed for physical activities.',
    },
    {
      'word': 'SAFETY',
      'hint': 'Industrial goggles.',
      'details': 'Protective eyewear used in hazardous work environments.',
    },
    {
      'word': 'CASE',
      'hint': 'Glasses holder.',
      'details': 'Protective storage for spectacles and contact lenses.',
    },
    {
      'word': 'CLOTH',
      'hint': 'Microfiber cleaner.',
      'details': 'Specialized fabric for removing oils from lens surfaces.',
    },
    {
      'word': 'DROP',
      'hint': 'Medicine delivery.',
      'details': 'Fluid unit used for administering topical eye medication.',
    },
    {
      'word': 'SNELL',
      'hint': 'Optics law names.',
      'details':
          'Scientist Willebrord Snellius, known for the law of refraction.',
    },
    {
      'word': 'FLUID',
      'hint': 'Intraocular liquid.',
      'details': 'Aqueous or vitreous humor that maintains eye pressure.',
    },
    {
      'word': 'FUNGAL',
      'hint': 'Infection category.',
      'details': 'Ocular condition caused by yeast or mold pathogens.',
    },
    {
      'word': 'FUNDUS',
      'hint': 'The back of the interior.',
      'details': 'The interior surface of the eye opposite the lens.',
    },
    {
      'word': 'SPHERE',
      'hint': 'Main correction part.',
      'details':
          'The primary part of an eye prescription for distance or near.',
    },
    {
      'word': 'BLOOD',
      'hint': 'Diabetic leakage.',
      'details': 'Fluid leaked into the eye during retinal pathologies.',
    },
    {
      'word': 'LASHES',
      'hint': 'Eyelid hair fringe.',
      'details': 'Protective hairs that prevent debris from entering the eye.',
    },
    {
      'word': 'VEIN',
      'hint': 'Return blood vessel.',
      'details': 'Carrier that drains deoxygenated blood from ocular tissues.',
    },
    {
      'word': 'ANGLE',
      'hint': 'Fluid exit point.',
      'details': 'The junction where the cornea and iris meet externally.',
    },
    {
      'word': 'STAIN',
      'hint': 'Health check dye.',
      'details': 'Fluorescein used to locate corneal scratches or dry spots.',
    },
    {
      'word': 'ZONULE',
      'hint': 'Lens suspension fiber.',
      'details': 'Thread-like structures holding the lens to the ciliary body.',
    },
    {
      'word': 'RECTUS',
      'hint': 'Straight eye muscle.',
      'details': 'One of the four muscles that move the eye in straight lines.',
    },
    {
      'word': 'SULCUS',
      'hint': 'Space behind iris.',
      'details': 'The anatomical groove located between the iris and ciliary.',
    },
    {
      'word': 'PLICA',
      'hint': 'Conjunctional fold.',
      'details': 'Small semilunar fold of conjunctiva at the inner corner.',
    },
    {
      'word': 'FACET',
      'hint': 'Lens edge detail.',
      'details':
          'A small surface carved into the periphery of an optical lens.',
    },
    {
      'word': 'SLANT',
      'hint': 'Tilted ocular gaze.',
      'details': 'Oblique positioning of the eyes or an optical axis.',
    },
    {
      'word': 'BEND',
      'hint': 'What refraction does.',
      'details': 'The change in direction of light as it enters a new medium.',
    },
    {
      'word': 'POWER',
      'hint': 'Correction amount.',
      'details': 'Refractive strength of a lens measured in Diopters.',
    },
    {
      'word': 'TORIC',
      'hint': 'Astigmatism lens.',
      'details':
          'Lens with different powers in two perpendicular orientations.',
    },
    {
      'word': 'VERTEX',
      'hint': 'Eye to lens gap.',
      'details':
          'Distance between the back of a lens and the front of the eye.',
    },
    {
      'word': 'ADD',
      'hint': 'Reading correction.',
      'details': 'Extra power added to the bottom of multifocal lenses.',
    },
    {
      'word': 'CLEAR',
      'hint': 'Crystal transparent.',
      'details': 'Absence of tint or opacity in an ocular or lens structure.',
    },
    {
      'word': 'HARD',
      'hint': 'Non-soft contact.',
      'details': 'Rigid Gas Permeable (RGP) contact lens material.',
    },
    {
      'word': 'SOFT',
      'hint': 'Standard contact.',
      'details': 'Flexible, water-absorbing hydrogel contact lens material.',
    },
    {
      'word': 'DAILY',
      'hint': 'One-day wear lens.',
      'details': 'Contact lenses discarded after a single day of use.',
    },
    {
      'word': 'MONTH',
      'hint': 'Longer wear lens.',
      'details': 'Contact lenses designed to be replaced every 30 days.',
    },
    {
      'word': 'RINSE',
      'hint': 'To wash the surface.',
      'details': 'Removing debris or preservatives with saline solution.',
    },
    {
      'word': 'DROPS',
      'hint': 'Dry eye treatment.',
      'details': 'Lubricating artificial tears used to treat dryness.',
    },
    {
      'word': 'STEAM',
      'hint': 'Lens fogging cause.',
      'details':
          'Condensation formed on lens surfaces during temperature shifts.',
    },
    {
      'word': 'GAZING',
      'hint': 'Steady eye focus.',
      'details': 'Prolonged fixated look maintained on a specific target.',
    },
    {
      'word': 'PEEK',
      'hint': 'Brief ocular look.',
      'details': 'Quick or secretive visual examination of an object.',
    },
    {
      'word': 'PRISM',
      'hint': 'Light shifter tool.',
      'details': 'A transparent element used to diverge or displace light.',
    },
    {
      'word': 'LASER',
      'hint': 'Coherent light beam.',
      'details': 'Highly focused radiation used in delicate eye surgeries.',
    },
    {
      'word': 'FOVEA',
      'hint': 'Macula center pit.',
      'details': 'The point of highest resolution at the center of the macula.',
    },
  ];

  late List<Map<String, String>> _shuffledWordData;

  int _level = 1;
  late String _targetWord;
  late String _hint;
  late String _details;
  final List<String> _guesses = [];
  String _currentGuess = "";
  final int _maxGuesses = 6;
  bool _isGameOver = false;
  bool _isWin = false;
  bool _hasGameStarted = false; // For persistent game background

  void _loadProgress() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final provider = context.read<GameProvider>();
    final progress = provider.getProgress('eye_quest');

    setState(() {
      _level = progress?.currentLevel ?? 1;

      // FIRST 30 are familiar, 31-100 are advanced
      var familiar = _allWordData.sublist(0, 30);
      var advanced = _allWordData.sublist(30);

      final seed = user.uid.hashCode;
      final random = math.Random(seed);

      // Shuffle within tiers
      familiar.shuffle(random);
      advanced.shuffle(random);

      _shuffledWordData = familiar + advanced;

      _initLevel(shouldStartGame: false);
    });
  }

  void _pauseGame() {
    if (_isGameOver) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => GamePauseDialog(
        gameTitle: 'Eye Quest',
        onResume: () => Navigator.pop(context),
        onRestart: () {
          Navigator.pop(context);
          setState(() {
            _initLevel();
          });
        },
        onExit: () {
          Navigator.pop(context); // Close dialog
          Navigator.pop(context); // Exit game
        },
      ),
    );
  }

  void _initLevel({bool shouldStartGame = true}) {
    final data = _shuffledWordData[(_level - 1) % _shuffledWordData.length];
    _targetWord = data['word']!.toUpperCase();
    _hint = data['hint']!;
    _details = data['details']!;
    _guesses.clear();
    _currentGuess = "";
    _isGameOver = false;
    _isWin = false;
    _hasGameStarted = shouldStartGame;
  }

  void _onKeyTap(String key) {
    if (_isGameOver) return;

    setState(() {
      if (key == 'DEL') {
        if (_currentGuess.isNotEmpty) {
          AudioService().playKeyDelete(); // Delete sound
          _currentGuess = _currentGuess.substring(0, _currentGuess.length - 1);
        }
      } else if (key == 'ENTER') {
        if (_currentGuess.length == _targetWord.length) {
          _submitGuess();
        }
      } else {
        if (_currentGuess.length < _targetWord.length) {
          AudioService().playKeyTap(); // Type sound
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
      AudioService().playWordCorrect(); // Correct word (green)
      _saveProgress();
    } else if (_guesses.length >= _maxGuesses) {
      _isGameOver = true;
      AudioService().playPuzzleGameOver(); // Game over
    } else {
      // Check if partial match (has some correct letters)
      bool hasCorrectLetters = false;
      for (int i = 0; i < _currentGuess.length; i++) {
        if (_targetWord.contains(_currentGuess[i])) {
          hasCorrectLetters = true;
          break;
        }
      }
      if (hasCorrectLetters) {
        AudioService().playWordPartial(); // Partial match (yellow)
      }
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
      AudioService().playPuzzleLevelUp(); // Level up
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (!_isGameOver && _hasGameStarted) {
          _pauseGame();
        } else if (!_hasGameStarted) {
          Navigator.pop(context);
        }
      },
      canPop: _isGameOver,
      child: Scaffold(
        backgroundColor: context.scaffoldBackground,
        body: Stack(
          children: [
            // Game Layer (Always visible once started)
            if (_hasGameStarted)
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      context.isDarkMode
                          ? context.primary.withValues(alpha: 0.1)
                          : context.scaffoldBackground,
                      context.scaffoldBackground,
                      context.scaffoldBackground,
                    ],
                  ),
                ),
                child: SafeArea(
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
              ),

            // Intro Screen (Before game starts)
            if (!_hasGameStarted) _buildPremiumIntro(),

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
            icon: Icon(Icons.arrow_back_rounded, color: context.textPrimary),
            onPressed: () {
              if (_isGameOver) {
                Navigator.pop(context);
              } else {
                _pauseGame();
              }
            },
          ),
          Column(
            children: [
              Text(
                'EYE QUEST',
                style: TextStyle(
                  color: context.textPrimary,
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
          IconButton(
            icon: Icon(
              Icons.pause_circle_filled_rounded,
              color: context.textPrimary,
              size: 28,
            ),
            onPressed: _pauseGame,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildHint() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surface,
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
            style: TextStyle(
              color: context.textSecondary,
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
        final double wordLen = _targetWord.length.toDouble();
        const double marginPerBox =
            6.0; // EdgeInsets.all(3) means 6px horizontal

        // Dynamically calculate box size considering all margins
        final double boxSize =
            ((availableWidth - (wordLen * marginPerBox)) / wordLen).clamp(
              25.0,
              55.0,
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
                  Color borderColor = context.dividerColor.withValues(
                    alpha: 0.2,
                  );

                  if (rowIndex < _guesses.length) {
                    if (_targetWord[colIndex] == char) {
                      bgColor = Colors.green.withValues(alpha: 0.6);
                      borderColor = Colors.green;
                    } else if (_targetWord.contains(char)) {
                      bgColor = Colors.amber.withValues(alpha: 0.6);
                      borderColor = Colors.amber;
                    } else {
                      bgColor = context.isDarkMode
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.grey.withValues(alpha: 0.2);
                      borderColor = context.dividerColor.withValues(alpha: 0.1);
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
                              color:
                                  (rowIndex < _guesses.length &&
                                      (bgColor ==
                                              Colors.green.withValues(
                                                alpha: 0.6,
                                              ) ||
                                          bgColor ==
                                              Colors.amber.withValues(
                                                alpha: 0.6,
                                              )))
                                  ? Colors.white
                                  : context.textPrimary,
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
                      color: context.surface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: context.dividerColor.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Center(
                      child: isDel
                          ? Icon(
                              Icons.backspace_outlined,
                              color: context.textPrimary,
                              size: 20,
                            )
                          : Text(
                              key,
                              style: TextStyle(
                                color: context.textPrimary,
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
      color: Colors.black.withValues(alpha: 0.7),
      child: Center(
        child: SingleChildScrollView(
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
                  style: TextStyle(
                    color: context.textPrimary,
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
                  style: TextStyle(color: context.textSecondary),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: context.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: context.dividerColor.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'CONCEPT',
                        style: TextStyle(
                          color: Colors.grey,
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
                      const SizedBox(height: 8),
                      const Divider(),
                      const SizedBox(height: 8),
                      Text(
                        'CLINICAL SIGNIFICANCE',
                        style: TextStyle(
                          color: context.textTertiary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _details,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: context.textSecondary,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _level++;
                      _initLevel();
                    });
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
                    _isWin ? 'NEXT LEVEL' : 'NEXT CONCEPT',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (!_isWin)
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'EXIT',
                      style: TextStyle(color: context.textTertiary),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumIntro() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            context.scaffoldBackground,
            context.scaffoldBackground.withValues(alpha: 0.95),
            context.scaffoldBackground.withValues(alpha: 0.9),
          ],
        ),
      ),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 24,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 450),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Shimmering Icon
                      Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: context.primary.withValues(alpha: 0.1),
                              border: Border.all(
                                color: context.primary,
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: context.primary.withValues(alpha: 0.3),
                                  blurRadius: 40,
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.visibility_rounded,
                              size: 56,
                              color: context.primary,
                            ),
                          )
                          .animate(onPlay: (c) => c.repeat())
                          .shimmer(duration: 2.seconds)
                          .animate()
                          .scale(duration: 600.ms, curve: Curves.elasticOut),
                      const SizedBox(height: 24),
                      Text(
                        'EYE QUEST',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 6,
                          shadows: [
                            Shadow(color: context.primary, blurRadius: 15),
                          ],
                        ),
                      ).animate().fadeIn(duration: 400.ms),
                      const SizedBox(height: 4),
                      Text(
                        'Clinical Lexical Mission',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: context.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ).animate().fadeIn(delay: 100.ms),
                      const SizedBox(height: 16),
                      Text(
                        'Master eye anatomy and clinical terminology through visual word puzzles. Sharpen your medical focus.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: context.textSecondary,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ).animate().fadeIn(delay: 200.ms),
                      const SizedBox(height: 24),
                      // Benefits Section
                      _buildPremiumBenefit(
                        Icons.remove_red_eye_rounded,
                        'Anatomy Mastery',
                        'Learn core parts of human eye.',
                      ),
                      _buildPremiumBenefit(
                        Icons.medical_services_rounded,
                        'Clinical Literacy',
                        'Master medical-grade terminology.',
                      ),
                      _buildPremiumBenefit(
                        Icons.psychology_rounded,
                        'Cognitive Focus',
                        'Strategic word building puzzles.',
                      ),
                      const SizedBox(height: 32),
                      // Actions
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _initLevel();
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: context.primary,
                            foregroundColor: context.onPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            elevation: 12,
                          ),
                          child: const Text(
                            'BEGIN MISSION',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                      ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.3),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Return to Games',
                          style: TextStyle(
                            color: context.textTertiary,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPremiumBenefit(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: context.dividerColor.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: context.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: context.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: context.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
