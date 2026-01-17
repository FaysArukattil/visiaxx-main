import 'dart:math';
import 'package:flutter/material.dart';
import '../../features/eye_care_tips/models/eye_care_tip_model.dart';

class EyeCareTipsData {
  // Category 1: Screen & Digital Eye Care
  static const screenTips = [
    EyeCareTip(
      id: 'screen_1',
      title: '20-20-20 Rule',
      description:
          'Look 20 feet away for 20 seconds every 20 minutes to relax eye muscles and reduce strain from prolonged screen use.',
      icon: Icons.timer_outlined,
      category: 'screen',
    ),
    EyeCareTip(
      id: 'screen_2',
      title: 'Blink Consciously',
      description:
          'Blink frequently while using digital screens to prevent dryness. People naturally blink less when staring at screens.',
      icon: Icons.visibility_outlined,
      category: 'screen',
    ),
    EyeCareTip(
      id: 'screen_3',
      title: 'Screen Positioning',
      description:
          'Keep screens at eye level or slightly below to reduce strain on eye and neck muscles. Avoid placing screens too close.',
      icon: Icons.straighten,
      category: 'screen',
    ),
    EyeCareTip(
      id: 'screen_4',
      title: 'Brightness Balance',
      description:
          'Adjust screen brightness to match room lighting to prevent glare. Excess brightness can irritate your eyes.',
      icon: Icons.brightness_6_outlined,
      category: 'screen',
    ),
    EyeCareTip(
      id: 'screen_5',
      title: 'Night Mode',
      description:
          'Use dark mode or blue-light filters during night use to reduce eye fatigue and minimize sleep disturbance.',
      icon: Icons.nightlight_outlined,
      category: 'screen',
    ),
    EyeCareTip(
      id: 'screen_6',
      title: 'Proper Distance',
      description:
          'Maintain at least an arm\'s length distance from screens. Sitting too close significantly increases eye strain.',
      icon: Icons.social_distance,
      category: 'screen',
    ),
    EyeCareTip(
      id: 'screen_7',
      title: 'Clean Screens',
      description:
          'Regularly clean your screen to reduce glare and dust exposure. Dirty screens force your eyes to work harder.',
      icon: Icons.cleaning_services_outlined,
      category: 'screen',
    ),
    EyeCareTip(
      id: 'screen_8',
      title: 'Avoid Dark Rooms',
      description:
          'Avoid using screens in complete darkness. The sudden contrast between bright screen and dark room strains eyes.',
      icon: Icons.light_mode_outlined,
      category: 'screen',
    ),
    EyeCareTip(
      id: 'screen_9',
      title: 'Increase Text Size',
      description:
          'Increase text size instead of leaning closer to the screen. This helps maintain a healthy viewing distance.',
      icon: Icons.text_fields,
      category: 'screen',
    ),
    EyeCareTip(
      id: 'screen_10',
      title: 'Regular Breaks',
      description:
          'Take short screen breaks even if eyes feel fine. Eye strain often builds up silently over extended periods.',
      icon: Icons.pause_circle_outline,
      category: 'screen',
    ),
    EyeCareTip(
      id: 'screen_11',
      title: 'Limit Scrolling',
      description:
          'Avoid continuous scrolling for long periods. Pause frequently to allow your eyes proper rest and relaxation.',
      icon: Icons.swap_vert,
      category: 'screen',
    ),
    EyeCareTip(
      id: 'screen_12',
      title: 'Anti-Glare Protection',
      description:
          'Use anti-glare screen protectors when available. They reduce reflections and improve viewing comfort.',
      icon: Icons.shield_outlined,
      category: 'screen',
    ),
  ];

  // Category 2: Daily Eye Care Habits
  static const dailyTips = [
    EyeCareTip(
      id: 'daily_1',
      title: 'Hand Hygiene',
      description:
          'Always wash hands before touching your eyes to prevent infections. Germs easily spread through eye contact.',
      icon: Icons.wash_outlined,
      category: 'daily',
    ),
    EyeCareTip(
      id: 'daily_2',
      title: 'Don\'t Rub Eyes',
      description:
          'Avoid rubbing your eyes, especially when they itch. Rubbing can damage the cornea and introduce harmful bacteria.',
      icon: Icons.do_not_touch_outlined,
      category: 'daily',
    ),
    EyeCareTip(
      id: 'daily_3',
      title: 'Quality Sleep',
      description:
          'Get adequate sleep to allow your eyes to recover naturally. Poor sleep directly causes dryness and redness.',
      icon: Icons.bedtime_outlined,
      category: 'daily',
    ),
    EyeCareTip(
      id: 'daily_4',
      title: 'Daily Face Wash',
      description:
          'Wash your face daily to remove dust and pollutants near the eyes. Clean skin helps maintain proper eye hygiene.',
      icon: Icons.face_retouching_natural,
      category: 'daily',
    ),
    EyeCareTip(
      id: 'daily_5',
      title: 'Clean Towels',
      description:
          'Use clean towels and avoid sharing them with others. Shared towels can easily transmit eye infections.',
      icon: Icons.dry_cleaning_outlined,
      category: 'daily',
    ),
    EyeCareTip(
      id: 'daily_6',
      title: 'Blinking Exercises',
      description:
          'Practice gentle eye blinking exercises during breaks. This improves natural tear distribution across eyes.',
      icon: Icons.fitbit_outlined,
      category: 'daily',
    ),
    EyeCareTip(
      id: 'daily_7',
      title: 'Balanced Lighting',
      description:
          'Avoid reading in very dim or very bright light. Balanced lighting significantly reduces eye stress and strain.',
      icon: Icons.lightbulb_outline,
      category: 'daily',
    ),
    EyeCareTip(
      id: 'daily_8',
      title: 'Good Posture',
      description:
          'Maintain proper posture while reading or working. Poor posture can indirectly strain your eyes over time.',
      icon: Icons.accessibility_new,
      category: 'daily',
    ),
    EyeCareTip(
      id: 'daily_9',
      title: 'Stay Hydrated',
      description:
          'Keep your eyes hydrated by drinking enough water daily. Dehydration significantly worsens dry eye symptoms.',
      icon: Icons.water_drop_outlined,
      category: 'daily',
    ),
    EyeCareTip(
      id: 'daily_10',
      title: 'Fresh Cosmetics',
      description:
          'Avoid using expired eye cosmetics or products. Old cosmetic products may harbor harmful bacteria.',
      icon: Icons.face_4_outlined,
      category: 'daily',
    ),
    EyeCareTip(
      id: 'daily_11',
      title: 'Remove Makeup',
      description:
          'Remove all eye makeup completely before sleeping. Leftover makeup can block glands and cause irritation.',
      icon: Icons.remove_circle_outline,
      category: 'daily',
    ),
    EyeCareTip(
      id: 'daily_12',
      title: 'Gradual Adjustment',
      description:
          'Avoid sudden exposure to bright sunlight after darkness. Gradual light adjustment helps protect your eyes.',
      icon: Icons.wb_twilight_outlined,
      category: 'daily',
    ),
  ];

  // Category 3: Nutrition & Eye Health
  static const nutritionTips = [
    EyeCareTip(
      id: 'nutrition_1',
      title: 'Vitamin A Foods',
      description:
          'Eat foods rich in vitamin A like carrots and spinach. Vitamin A supports good vision and eye surface health.',
      icon: Icons.restaurant_outlined,
      category: 'nutrition',
    ),
    EyeCareTip(
      id: 'nutrition_2',
      title: 'Leafy Greens',
      description:
          'Include leafy green vegetables in your diet regularly. They help protect against age-related eye issues.',
      icon: Icons.eco_outlined,
      category: 'nutrition',
    ),
    EyeCareTip(
      id: 'nutrition_3',
      title: 'Omega-3 Rich Foods',
      description:
          'Consume omega-3 rich foods like fish or flaxseeds. These essential fats help reduce dry eye symptoms.',
      icon: Icons.set_meal_outlined,
      category: 'nutrition',
    ),
    EyeCareTip(
      id: 'nutrition_4',
      title: 'Citrus Fruits',
      description:
          'Add citrus fruits to your diet for vitamin C. Vitamin C supports and strengthens eye blood vessels.',
      icon: Icons.apple_outlined,
      category: 'nutrition',
    ),
    EyeCareTip(
      id: 'nutrition_5',
      title: 'Nuts & Seeds',
      description:
          'Nuts and seeds provide vitamin E for eye protection. They help slow age-related eye damage effectively.',
      icon: Icons.grain_outlined,
      category: 'nutrition',
    ),
    EyeCareTip(
      id: 'nutrition_6',
      title: 'Daily Hydration',
      description:
          'Drink enough water daily to keep eyes properly hydrated. Dry eyes are often directly linked to dehydration.',
      icon: Icons.local_drink_outlined,
      category: 'nutrition',
    ),
    EyeCareTip(
      id: 'nutrition_7',
      title: 'Reduce Sugar',
      description:
          'Reduce excessive sugar intake in your diet. High sugar levels can negatively affect eye health over time.',
      icon: Icons.cake_outlined,
      category: 'nutrition',
    ),
    EyeCareTip(
      id: 'nutrition_8',
      title: 'Fresh Foods',
      description:
          'Limit processed foods and increase fresh food intake. Fresh nutrients support long-term vision health better.',
      icon: Icons.local_grocery_store_outlined,
      category: 'nutrition',
    ),
    EyeCareTip(
      id: 'nutrition_9',
      title: 'Zinc Sources',
      description:
          'Include zinc-rich foods like legumes and whole grains. Zinc helps transport vitamin A to the eyes.',
      icon: Icons.lunch_dining_outlined,
      category: 'nutrition',
    ),
    EyeCareTip(
      id: 'nutrition_10',
      title: 'Limit Caffeine',
      description:
          'Avoid excessive caffeine if you experience dry eyes. Caffeine can significantly increase dehydration levels.',
      icon: Icons.local_cafe_outlined,
      category: 'nutrition',
    ),
    EyeCareTip(
      id: 'nutrition_11',
      title: 'Balanced Diet',
      description:
          'Maintain a balanced diet instead of relying on supplements. Natural food sources are better absorbed by body.',
      icon: Icons.balance_outlined,
      category: 'nutrition',
    ),
    EyeCareTip(
      id: 'nutrition_12',
      title: 'Consult Doctor',
      description:
          'Consult a doctor before taking eye supplements. Not all supplements are necessary or beneficial for everyone.',
      icon: Icons.medical_information_outlined,
      category: 'nutrition',
    ),
  ];

  // Category 4: Eye Protection & Safety
  static const protectionTips = [
    EyeCareTip(
      id: 'protection_1',
      title: 'UV Protection',
      description:
          'Wear sunglasses that block UV rays when outdoors. UV exposure can damage eye tissues over extended time.',
      icon: Icons.wb_sunny_outlined,
      category: 'protection',
    ),
    EyeCareTip(
      id: 'protection_2',
      title: 'Sports Eyewear',
      description:
          'Use protective eyewear during sports or risky activities. This effectively prevents accidental eye injuries.',
      icon: Icons.sports_baseball_outlined,
      category: 'protection',
    ),
    EyeCareTip(
      id: 'protection_3',
      title: 'Never Look at Sun',
      description:
          'Avoid looking directly at the sun, even during eclipses. Direct sunlight can cause permanent eye damage.',
      icon: Icons.flare_outlined,
      category: 'protection',
    ),
    EyeCareTip(
      id: 'protection_4',
      title: 'Chemical Safety',
      description:
          'Keep chemicals and sprays away from your eyes. Always carefully read and follow safety instructions.',
      icon: Icons.science_outlined,
      category: 'protection',
    ),
    EyeCareTip(
      id: 'protection_5',
      title: 'Safety Goggles',
      description:
          'Use safety goggles while working with tools or machinery. Most eye injuries are preventable with protection.',
      icon: Icons.remove_red_eye_outlined,
      category: 'protection',
    ),
    EyeCareTip(
      id: 'protection_6',
      title: 'Firework Safety',
      description:
          'Avoid fireworks or sharp objects near your face. Sudden accidents can cause severe and permanent damage.',
      icon: Icons.warning_amber_outlined,
      category: 'protection',
    ),
    EyeCareTip(
      id: 'protection_7',
      title: 'Child Safety',
      description:
          'Keep all sharp objects away from children\'s reach. Many preventable eye injuries occur at home with children.',
      icon: Icons.child_care_outlined,
      category: 'protection',
    ),
    EyeCareTip(
      id: 'protection_8',
      title: 'Night Driving',
      description:
          'Avoid driving at night if you experience poor night vision. Glare can significantly increase accident risk.',
      icon: Icons.drive_eta_outlined,
      category: 'protection',
    ),
    EyeCareTip(
      id: 'protection_9',
      title: 'Mirror Adjustment',
      description:
          'Adjust car mirrors properly to reduce glare while driving. This improves night driving comfort and safety.',
      icon: Icons.car_crash_outlined,
      category: 'protection',
    ),
    EyeCareTip(
      id: 'protection_10',
      title: 'Avoid Smoking',
      description:
          'Avoid smoking or exposure to smoke environments. Smoking significantly increases risk of eye diseases.',
      icon: Icons.smoke_free_outlined,
      category: 'protection',
    ),
    EyeCareTip(
      id: 'protection_11',
      title: 'Dust Protection',
      description:
          'Keep eyes protected from dust in windy conditions. Dust particles can irritate and infect eyes easily.',
      icon: Icons.air_outlined,
      category: 'protection',
    ),
    EyeCareTip(
      id: 'protection_12',
      title: 'Helmet Visors',
      description:
          'Use helmets with visors when riding two-wheelers. They protect eyes from debris, wind, and insects.',
      icon: Icons.two_wheeler_outlined,
      category: 'protection',
    ),
  ];

  // Category 5: Glasses & Contact Lens Care
  static const glassesTips = [
    EyeCareTip(
      id: 'glasses_1',
      title: 'Wear Prescribed Glasses',
      description:
          'Wear prescribed glasses regularly as advised by eye doctor. Skipping them can worsen eye strain significantly.',
      icon: Icons.visibility_outlined,
      category: 'glasses',
    ),
    EyeCareTip(
      id: 'glasses_2',
      title: 'Clean Daily',
      description:
          'Clean glasses daily with a microfiber cloth for clear vision. Dirty lenses reduce clarity and strain eyes.',
      icon: Icons.cleaning_services_outlined,
      category: 'glasses',
    ),
    EyeCareTip(
      id: 'glasses_3',
      title: 'Proper Cleaning',
      description:
          'Never use water or rough fabric to clean lenses. This can damage protective lens coating permanently.',
      icon: Icons.water_damage_outlined,
      category: 'glasses',
    ),
    EyeCareTip(
      id: 'glasses_4',
      title: 'Regular Checkups',
      description:
          'Get your eye power checked every 1-2 years regularly. Vision can change gradually without you noticing.',
      icon: Icons.date_range_outlined,
      category: 'glasses',
    ),
    EyeCareTip(
      id: 'glasses_5',
      title: 'Don\'t Share',
      description:
          'Avoid wearing someone else\'s glasses ever. Incorrect power can cause headaches and further strain.',
      icon: Icons.person_off_outlined,
      category: 'glasses',
    ),
    EyeCareTip(
      id: 'glasses_6',
      title: 'Lens Hygiene',
      description:
          'Follow proper hygiene when using contact lenses. Poor hygiene significantly increases infection risk.',
      icon: Icons.clean_hands_outlined,
      category: 'glasses',
    ),
    EyeCareTip(
      id: 'glasses_7',
      title: 'No Sleeping',
      description:
          'Never sleep with contact lenses unless specifically prescribed. Sleeping with lenses reduces oxygen to eyes.',
      icon: Icons.hotel_outlined,
      category: 'glasses',
    ),
    EyeCareTip(
      id: 'glasses_8',
      title: 'Fresh Solution',
      description:
          'Replace contact lens solution daily without fail. Reusing old solution actively promotes bacterial growth.',
      icon: Icons.update_outlined,
      category: 'glasses',
    ),
    EyeCareTip(
      id: 'glasses_9',
      title: 'Usage Duration',
      description:
          'Do not exceed recommended lens usage duration ever. Overuse can damage the cornea and cause infections.',
      icon: Icons.timer_off_outlined,
      category: 'glasses',
    ),
    EyeCareTip(
      id: 'glasses_10',
      title: 'Clean Cases',
      description:
          'Store lenses in clean cases and replace cases regularly. Dirty cases harbor germs and bacteria.',
      icon: Icons.storage_outlined,
      category: 'glasses',
    ),
    EyeCareTip(
      id: 'glasses_11',
      title: 'Remove if Painful',
      description:
          'Remove contact lenses immediately if eyes feel painful or red. Seek medical advice promptly if needed.',
      icon: Icons.emergency_outlined,
      category: 'glasses',
    ),
    EyeCareTip(
      id: 'glasses_12',
      title: 'No Swimming',
      description:
          'Avoid wearing contact lenses while swimming in pools. Water significantly increases infection risk for eyes.',
      icon: Icons.pool_outlined,
      category: 'glasses',
    ),
  ];

  // Category 6: Medical & Preventive Eye Care
  static const medicalTips = [
    EyeCareTip(
      id: 'medical_1',
      title: 'Regular Checkups',
      description:
          'Get regular eye checkups even if vision feels completely normal. Many eye diseases are symptom-free early.',
      icon: Icons.calendar_today_outlined,
      category: 'medical',
    ),
    EyeCareTip(
      id: 'medical_2',
      title: 'Sudden Changes',
      description:
          'Seek immediate care for any sudden vision changes. Early treatment can prevent permanent eye damage.',
      icon: Icons.warning_outlined,
      category: 'medical',
    ),
    EyeCareTip(
      id: 'medical_3',
      title: 'Diabetes Care',
      description:
          'Monitor eye health closely if you have diabetes. Diabetes can significantly affect retinal health over time.',
      icon: Icons.monitor_heart_outlined,
      category: 'medical',
    ),
    EyeCareTip(
      id: 'medical_4',
      title: 'No Self-Medication',
      description:
          'Avoid self-medicating with random eye drops. Incorrect drops may worsen existing conditions significantly.',
      icon: Icons.medication_outlined,
      category: 'medical',
    ),
    EyeCareTip(
      id: 'medical_5',
      title: 'Follow Treatment',
      description:
          'Follow prescribed treatment plans strictly and completely. Skipping doses reduces treatment effectiveness greatly.',
      icon: Icons.assignment_turned_in_outlined,
      category: 'medical',
    ),
    EyeCareTip(
      id: 'medical_6',
      title: 'Report Symptoms',
      description:
          'Inform your doctor about persistent redness or pain. These may indicate serious underlying issues needing attention.',
      icon: Icons.report_problem_outlined,
      category: 'medical',
    ),
    EyeCareTip(
      id: 'medical_7',
      title: 'Vision Headaches',
      description:
          'Do not ignore frequent headaches related to vision. They may signal eye strain or power changes.',
      icon: Icons.headset_off_outlined,
      category: 'medical',
    ),
    EyeCareTip(
      id: 'medical_8',
      title: 'Child Screenings',
      description:
          'Children should have early comprehensive eye screenings. Early detection supports healthy visual development always.',
      icon: Icons.child_friendly_outlined,
      category: 'medical',
    ),
    EyeCareTip(
      id: 'medical_9',
      title: 'Senior Care',
      description:
          'Elderly individuals should regularly check for cataracts and glaucoma. Early diagnosis greatly improves outcomes.',
      icon: Icons.elderly_outlined,
      category: 'medical',
    ),
    EyeCareTip(
      id: 'medical_10',
      title: 'No Steroids',
      description:
          'Avoid using steroid eye drops without prescription ever. Misuse can dangerously increase eye pressure levels.',
      icon: Icons.block_outlined,
      category: 'medical',
    ),
    EyeCareTip(
      id: 'medical_11',
      title: 'Blood Pressure',
      description:
          'Maintain good control of blood pressure levels consistently. High BP can adversely affect eye blood vessels.',
      icon: Icons.favorite_border_outlined,
      category: 'medical',
    ),
    EyeCareTip(
      id: 'medical_12',
      title: 'Emergency Info',
      description:
          'Keep emergency eye care contact information readily handy. Quick action matters greatly in eye injuries.',
      icon: Icons.phone_in_talk_outlined,
      category: 'medical',
    ),
  ];

  static final List<EyeCareTipCategory> categories = [
    EyeCareTipCategory(
      id: 'screen',
      title: 'Screen & Digital Eye Care',
      emoji: '📱',
      color: const Color(0xFF6C63FF),
      tips: screenTips,
    ),
    EyeCareTipCategory(
      id: 'daily',
      title: 'Daily Eye Care Habits',
      emoji: '✨',
      color: const Color(0xFF4CAF50),
      tips: dailyTips,
    ),
    EyeCareTipCategory(
      id: 'nutrition',
      title: 'Nutrition & Eye Health',
      emoji: '🥗',
      color: const Color(0xFFFF9800),
      tips: nutritionTips,
    ),
    EyeCareTipCategory(
      id: 'protection',
      title: 'Eye Protection & Safety',
      emoji: '🛡️',
      color: const Color(0xFFF44336),
      tips: protectionTips,
    ),
    EyeCareTipCategory(
      id: 'glasses',
      title: 'Glasses & Contact Lens Care',
      emoji: '👓',
      color: const Color(0xFF2196F3),
      tips: glassesTips,
    ),
    EyeCareTipCategory(
      id: 'medical',
      title: 'Medical & Preventive Eye Care',
      emoji: '🩺',
      color: const Color(0xFF9C27B0),
      tips: medicalTips,
    ),
  ];

  /// Get tip of the day based on current date
  static EyeCareTip getTipOfTheDay() {
    final now = DateTime.now();
    // Create a stable seed for the day to keep the tip consistent throughout the day
    final daySeed = now.year * 10000 + now.month * 100 + now.day;
    final random = Random(daySeed);

    // Combine all tips from all categories
    final allTips = <EyeCareTip>[];
    for (var category in categories) {
      allTips.addAll(category.tips);
    }

    if (allTips.isEmpty) return screenTips.first;

    // Use random index based on the day's seed
    final tipIndex = random.nextInt(allTips.length);
    return allTips[tipIndex];
  }
}
