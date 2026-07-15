import '../utils/listing_sample_images.dart';

/// Dublin marketplace seed v1 (reference only) — superseded by [SampleListingsDublinV2].
abstract final class SampleListingsDublin {
  static List<Map<String, dynamic>> get items => List.unmodifiable(_raw);

  static var _sharePhotoSlot = 0;
  static var _rentPhotoSlot = 0;

  static final List<Map<String, dynamic>> _raw = [
    // ── Share (18) ───────────────────────────────────────────────
    _listing(
      id: 'dub-share-01',
      title: 'Female only · shared bed · Cherrywood',
      price: '625/month',
      location: 'Cherrywood, Dublin 18',
      type: 'Share',
      description:
          'Permanent stay. WiFi, bins, alarm, parking included. Electricity split. Luas 5 min. Shared with 1 couple + 1 male.',
      hostName: 'Priya N',
      hostCity: 'Cherrywood',
      hostLanguage: 'Telugu, English',
      hostMotherTongue: 'Telugu',
      foodPreference: 'Veg',
      roomType: 'Bed in shared room',
      currentOccupants: 3,
      preferredTenantOccupant: 'Working Professionals',
      preferredTenantFood: 'veg',
      bachelorPreference: 'Girls only',
    ),
    _listing(
      id: 'dub-share-02',
      title: 'Male only · €700/person · Rialto',
      price: '700/month',
      location: 'Rialto, Dublin 12',
      type: 'Share',
      description:
          'Short or long-term. Indian grocery 5 min walk. Rialto Luas 10 min. Bills per person on top of rent.',
      hostName: 'Arjun K',
      hostCity: 'Rialto',
      hostLanguage: 'Hindi, English',
      hostMotherTongue: 'Hindi',
      foodPreference: 'Non-veg',
      roomType: 'Private room',
      currentOccupants: 4,
      bachelorPreference: 'Boys only',
    ),
    _listing(
      id: 'dub-share-03',
      title: 'Ensuite · Dundrum · UCD bus',
      price: '1336/month',
      location: 'Dundrum, Dublin 14',
      type: 'Share',
      description:
          'Deposit equals rent. Green Luas 10 min. Gym and cinema in building. BER A-rated.',
      hostName: 'Meera S',
      hostCity: 'Dundrum',
      hostLanguage: 'Tamil, English',
      hostMotherTongue: 'Tamil',
      foodPreference: 'Veg',
      roomType: 'Ensuite',
      furnishing: 'Furnished',
      preferredTenantFood: 'veg',
    ),
    _listing(
      id: 'dub-share-04',
      title: 'All bills in · male · Dundalk DKIT',
      price: '350/month',
      location: 'Dundalk, County Louth',
      type: 'Share',
      description:
          'Opposite DKIT campus. 24/7 bus to city. Single bed in sharing room. No deposit.',
      hostName: 'Rahul V',
      hostCity: 'Dundalk',
      hostLanguage: 'Hindi, English',
      hostMotherTongue: 'Hindi',
      foodPreference: 'Veg',
      roomType: 'Bed in shared room',
      currentOccupants: 2,
      bachelorPreference: 'Boys only',
      occupantType: 'Students',
    ),
    _listing(
      id: 'dub-share-05',
      title: 'Bed space · female · Dublin 4 Luas',
      price: '650/month',
      location: 'Cherrywood, Dublin 18',
      type: 'Share',
      description:
          'Sharing with another female. WiFi + bins included. Deposit one month. Green Line Luas 5 min.',
      hostName: 'Anitha R',
      hostCity: 'Cherrywood',
      hostLanguage: 'Telugu, English',
      hostMotherTongue: 'Telugu',
      foodPreference: 'Veg',
      roomType: 'Bed in shared room',
      bachelorPreference: 'Girls only',
      preferredTenantFood: 'veg',
      languagesSpoken: const ['Telugu', 'Hindi'],
      lifestyleFlags: const ['vegetarian_household', 'no_smoking'],
      proximityData: const {
        'luas_line': 'Luas',
        'direct_destination': 'Citywest',
        'transit_headline': 'Direct Luas to Citywest',
        'has_direct_luas': true,
        'source': 'seed',
      },
      latitude: 53.2785,
      longitude: -6.1532,
    ),
    _listing(
      id: 'dub-share-06',
      title: 'Lime House · €800/person · multi-slot',
      price: '800/month',
      location: 'Dublin 4',
      type: 'Share',
      description:
          'Temp or long-term. 2 male / 2 female / couples. Gym, cinema, co-working. Grand Canal Dock walk.',
      hostName: 'Sanjay P',
      hostCity: 'Dublin 4',
      hostLanguage: 'English, Hindi',
      hostMotherTongue: 'English',
      foodPreference: 'Non-veg',
      roomType: 'Bed in shared room',
      currentOccupants: 6,
      bachelorPreference: 'Boys & Girls allowed',
    ),
    _listing(
      id: 'dub-share-07',
      title: 'Ensuite double · female · Two Oaks D16',
      price: '1050/month',
      location: 'Dublin 16',
      type: 'Share',
      description:
          '€1,050 + electricity. WiFi and bins free. Bus 15 (24h) and S8 nearby. Permanent stay.',
      hostName: 'Lakshmi I',
      hostCity: 'Dublin 16',
      hostLanguage: 'Malayalam, English',
      hostMotherTongue: 'Malayalam',
      foodPreference: 'Veg',
      roomType: 'Ensuite',
      furnishing: 'Furnished',
      bachelorPreference: 'Girls only',
    ),
    _listing(
      id: 'dub-share-08',
      title: 'Ensuite for 2 · Lucan · WFH desk',
      price: '1200/month',
      location: 'Lucan, Dublin',
      type: 'Share',
      description:
          'Couple or sharing pair OK. All bills except electricity. BER A2. 5Gbps internet. Bus to city 3 min.',
      hostName: 'Kiran M',
      hostCity: 'Lucan',
      hostLanguage: 'Kannada, English',
      hostMotherTongue: 'Kannada',
      foodPreference: 'Non-veg',
      roomType: 'Ensuite',
      furnishing: 'Furnished',
      bachelorPreference: 'Boys & Girls allowed',
      smokingAllowed: false,
    ),
    _listing(
      id: 'dub-share-09',
      title: 'Private room · veg kitchen · Rialto',
      price: '780/month',
      location: 'Rialto, Dublin 12',
      type: 'Share',
      description:
          'Strict veg household. Heuston Luas 5 min. Students welcome. 4 friendly housemates.',
      hostName: 'Divya S',
      hostCity: 'Rialto',
      hostLanguage: 'Telugu, English',
      hostMotherTongue: 'Telugu',
      foodPreference: 'Veg',
      roomType: 'Private room',
      currentOccupants: 4,
      preferredTenantFood: 'veg',
      occupantType: 'Students',
    ),
    _listing(
      id: 'dub-share-10',
      title: 'Professional house · Sandyford',
      price: '920/month',
      location: 'Dublin 18',
      type: 'Share',
      description:
          'Working professionals only. Parking +€50/mo optional. Luas Green 8 min. No smoking.',
      hostName: 'Vikram T',
      hostCity: 'Cherrywood',
      hostLanguage: 'Hindi, English',
      hostMotherTongue: 'Hindi',
      foodPreference: 'Non-veg',
      roomType: 'Private room',
      preferredTenantOccupant: 'Working Professionals',
      smokingAllowed: false,
    ),
    _listing(
      id: 'dub-share-11',
      title: 'Budget bed · Dundalk · all-in',
      price: '380/month',
      location: 'Dundalk, County Louth',
      type: 'Share',
      description:
          'Female preferred. Lidl 10 min walk. DKIT 5 min. Fully furnished shared house.',
      hostName: 'Neha G',
      hostCity: 'Dundalk',
      hostLanguage: 'Marathi, English',
      hostMotherTongue: 'Marathi',
      foodPreference: 'Veg',
      roomType: 'Bed in shared room',
      bachelorPreference: 'Girls only',
    ),
    _listing(
      id: 'dub-share-12',
      title: 'Glass Bottle · sea view · Dublin 4',
      price: '950/month',
      location: 'Dublin 4',
      type: 'Share',
      description:
          'Premium building. Sky lounge access. Silicon Docks walk. Deposit €950. Bills extra.',
      hostName: 'Rohit A',
      hostCity: 'Dublin 4',
      hostLanguage: 'Gujarati, English',
      hostMotherTongue: 'Gujarati',
      foodPreference: 'Veg',
      roomType: 'Private room',
      furnishing: 'Furnished',
    ),
    _listing(
      id: 'dub-share-13',
      title: 'Family-friendly spare room · Lucan',
      price: '600/month',
      location: 'Lucan, Dublin',
      type: 'Share',
      description:
          'Quiet estate. Couple with one child. Separate bathroom. Lidl/SuperValu 5 min.',
      hostName: 'Deepa K',
      hostCity: 'Lucan',
      hostLanguage: 'Tamil, English',
      hostMotherTongue: 'Tamil',
      foodPreference: 'Veg',
      roomType: 'Private room',
      occupantType: 'Family',
      preferredTenantOccupant: 'Family',
    ),
    _listing(
      id: 'dub-share-14',
      title: 'Twin room · UCD commute · Dundrum',
      price: '850/month',
      location: 'Dundrum, Dublin 14',
      type: 'Share',
      description:
          'Direct bus to UCD. Tesco Express in estate. 2 bed 2 bath apartment. Female only.',
      hostName: 'Pooja H',
      hostCity: 'Dundrum',
      hostLanguage: 'Hindi, English',
      hostMotherTongue: 'Hindi',
      foodPreference: 'Non-veg',
      roomType: 'Bed in shared room',
      bachelorPreference: 'Girls only',
    ),
    _listing(
      id: 'dub-share-15',
      title: 'Immediate · male · Rathmines area',
      price: '720/month',
      location: 'Dublin 12',
      type: 'Share',
      description:
          'Available now. Double bedroom can share. Dunnes 5 min. City centre bus 20 min.',
      hostName: 'Manoj B',
      hostCity: 'Rialto',
      hostLanguage: 'Bengali, English',
      hostMotherTongue: 'Bengali',
      foodPreference: 'Non-veg',
      roomType: 'Bed in shared room',
      bachelorPreference: 'Boys only',
    ),
    _listing(
      id: 'dub-share-16',
      title: 'Co-living · Dublin 16 · gym access',
      price: '1100/month',
      location: 'Dublin 16',
      type: 'Share',
      description:
          'Ensuite in new build. Party hall and tennis nearby. Any gender. Long-term preferred.',
      hostName: 'Aishwarya C',
      hostCity: 'Dublin 16',
      hostLanguage: 'Telugu, English',
      hostMotherTongue: 'Telugu',
      foodPreference: 'Veg',
      roomType: 'Ensuite',
      furnishing: 'Furnished',
      bachelorPreference: 'Boys & Girls allowed',
    ),
    _listing(
      id: 'dub-share-17',
      title: 'Tech corridor · Grand Canal Dock',
      price: '1150/month',
      location: 'Dublin 4',
      type: 'Share',
      description:
          'Near Google/Meta. Private room in 3 bed. Non-veg OK. Deposit matches rent.',
      hostName: 'Naveen L',
      hostCity: 'Dublin 4',
      hostLanguage: 'Telugu, English',
      hostMotherTongue: 'Telugu',
      foodPreference: 'Non-veg',
      roomType: 'Private room',
      preferredTenantOccupant: 'Working Professionals',
    ),
    _listing(
      id: 'dub-share-18',
      title: 'Student-friendly · Cherrywood Luas',
      price: '540/month',
      location: 'Cherrywood, Dublin 18',
      type: 'Share',
      description:
          'Bed in shared room. All utilities included except WiFi top-up. 3 parks nearby.',
      hostName: 'Shruti D',
      hostCity: 'Cherrywood',
      hostLanguage: 'Hindi, English',
      hostMotherTongue: 'Hindi',
      foodPreference: 'Veg',
      roomType: 'Bed in shared room',
      occupantType: 'Students',
      preferredTenantFood: 'veg',
    ),

    // ── Rent (18) — whole units ──────────────────────────────────
    _listing(
      id: 'dub-rent-01',
      title: '2 bed apartment · Cherrywood · Luas',
      price: '1850/month',
      location: 'Cherrywood, Dublin 18',
      type: 'Rent',
      description:
          'Unfurnished. Parking included. Green Line 6 min walk. RTB registered landlord.',
      hostName: 'Rajesh P',
      hostCity: 'Cherrywood',
      hostLanguage: 'Telugu, English',
      hostMotherTongue: 'Telugu',
      foodPreference: 'Veg',
      furnishing: 'Unfurnished',
      bedrooms: '2 bed',
    ),
    _listing(
      id: 'dub-rent-02',
      title: '1 bed · Dublin 4 · sea proximity',
      price: '2100/month',
      location: 'Dublin 4',
      type: 'Rent',
      description:
          'Fully furnished. All bills included. Sandymount Strand 10 min walk. Professionals preferred.',
      hostName: 'Elena M',
      hostCity: 'Dublin 4',
      hostLanguage: 'English',
      hostMotherTongue: 'English',
      foodPreference: 'Non-veg',
      furnishing: 'Furnished',
      bedrooms: '1 bed',
    ),
    _listing(
      id: 'dub-rent-03',
      title: '3 bed house · Dundrum D14',
      price: '2800/month',
      location: 'Dundrum, Dublin 14',
      type: 'Rent',
      description:
          'Family home. Large garden. Green Luas 12 min. Schools and Tesco nearby.',
      hostName: 'Sunil R',
      hostCity: 'Dundrum',
      hostLanguage: 'Hindi, English',
      hostMotherTongue: 'Hindi',
      foodPreference: 'Veg',
      furnishing: 'Semi-furnished',
      bedrooms: '3 bed',
      occupantType: 'Family',
    ),
    _listing(
      id: 'dub-rent-04',
      title: '2 bed · Lucan · commuter belt',
      price: '1650/month',
      location: 'Lucan, Dublin',
      type: 'Rent',
      description:
          'M50 access. Semi-furnished. Electricity tenant responsibility. Available September.',
      hostName: 'Amrita F',
      hostCity: 'Lucan',
      hostLanguage: 'Malayalam, English',
      hostMotherTongue: 'Malayalam',
      foodPreference: 'Veg',
      furnishing: 'Semi-furnished',
      bedrooms: '2 bed',
    ),
    _listing(
      id: 'dub-rent-05',
      title: '1 bed flat · Rialto D12',
      price: '1400/month',
      location: 'Rialto, Dublin 12',
      type: 'Rent',
      description:
          'City fringe. Heuston 5 min by Luas. Ideal for single professional. Deposit €1,400.',
      hostName: 'Imran S',
      hostCity: 'Rialto',
      hostLanguage: 'Urdu, English',
      hostMotherTongue: 'Urdu',
      foodPreference: 'Non-veg',
      furnishing: 'Furnished',
      bedrooms: '1 bed',
    ),
    _listing(
      id: 'dub-rent-06',
      title: '2 bed · Dundalk · near DKIT',
      price: '1200/month',
      location: 'Dundalk, County Louth',
      type: 'Rent',
      description:
          'Commuter option. Bus to Dublin. Quiet neighbourhood. Unfurnished.',
      hostName: 'Ciara O',
      hostCity: 'Dundalk',
      hostLanguage: 'English',
      hostMotherTongue: 'English',
      foodPreference: 'Non-veg',
      furnishing: 'Unfurnished',
      bedrooms: '2 bed',
    ),
    _listing(
      id: 'dub-rent-07',
      title: 'Modern 2 bed · Dublin 16',
      price: '1950/month',
      location: 'Dublin 16',
      type: 'Rent',
      description:
          'A-rated energy. Balcony. Two Oaks estate. Luas feeder bus at door.',
      hostName: 'Harish V',
      hostCity: 'Dublin 16',
      hostLanguage: 'Tamil, English',
      hostMotherTongue: 'Tamil',
      foodPreference: 'Veg',
      furnishing: 'Furnished',
      bedrooms: '2 bed',
    ),
    _listing(
      id: 'dub-rent-08',
      title: 'Studio · Grand Canal Dock',
      price: '1750/month',
      location: 'Dublin 4',
      type: 'Rent',
      description:
          'Compact studio for one. Gym in building. Walk to tech offices. Short let OK.',
      hostName: 'Patrick W',
      hostCity: 'Dublin 4',
      hostLanguage: 'English',
      hostMotherTongue: 'English',
      foodPreference: 'Non-veg',
      furnishing: 'Furnished',
      bedrooms: 'Studio',
    ),
    _listing(
      id: 'dub-rent-09',
      title: '3 bed semi-D · Cherrywood',
      price: '2650/month',
      location: 'Cherrywood, Dublin 18',
      type: 'Rent',
      description:
          'Driveway parking for 2 cars. Veg-friendly previous tenants. Near business park.',
      hostName: 'Kavitha N',
      hostCity: 'Cherrywood',
      hostLanguage: 'Telugu, English',
      hostMotherTongue: 'Telugu',
      foodPreference: 'Veg',
      furnishing: 'Semi-furnished',
      bedrooms: '3 bed',
    ),
    _listing(
      id: 'dub-rent-10',
      title: '1 bed · Dundrum shopping district',
      price: '1550/month',
      location: 'Dundrum, Dublin 14',
      type: 'Rent',
      description:
          'Above retail level noise minimal. Bus to UCD. WiFi included in rent.',
      hostName: 'Mohit J',
      hostCity: 'Dundrum',
      hostLanguage: 'Hindi, English',
      hostMotherTongue: 'Hindi',
      foodPreference: 'Non-veg',
      furnishing: 'Furnished',
      bedrooms: '1 bed',
    ),
    _listing(
      id: 'dub-rent-11',
      title: '2 bed cottage · Lucan',
      price: '1700/month',
      location: 'Lucan, Dublin',
      type: 'Rent',
      description:
          'Character home with backyard. Pet considered. Liffey Valley 10 min drive.',
      hostName: 'Sinead B',
      hostCity: 'Lucan',
      hostLanguage: 'English',
      hostMotherTongue: 'English',
      foodPreference: 'Non-veg',
      furnishing: 'Unfurnished',
      bedrooms: '2 bed',
    ),
    _listing(
      id: 'dub-rent-12',
      title: 'Luxury 2 bed · Glass Bottle',
      price: '3200/month',
      location: 'Dublin 4',
      type: 'Rent',
      description:
          'Premium finish. Concierge. Sea view balcony. Corporate lease welcome.',
      hostName: 'Aditya K',
      hostCity: 'Dublin 4',
      hostLanguage: 'Hindi, English',
      hostMotherTongue: 'Hindi',
      foodPreference: 'Non-veg',
      furnishing: 'Furnished',
      bedrooms: '2 bed',
    ),
    _listing(
      id: 'dub-rent-13',
      title: 'Affordable 1 bed · Rialto',
      price: '1250/month',
      location: 'Rialto, Dublin 12',
      type: 'Rent',
      description:
          'First-time renters welcome. Indian stores nearby. Bus 123 to city.',
      hostName: 'Fatima A',
      hostCity: 'Rialto',
      hostLanguage: 'Arabic, English',
      hostMotherTongue: 'Arabic',
      foodPreference: 'Non-veg',
      furnishing: 'Semi-furnished',
      bedrooms: '1 bed',
    ),
    _listing(
      id: 'dub-rent-14',
      title: '2 bed · Dundalk town centre',
      price: '1100/month',
      location: 'Dundalk, County Louth',
      type: 'Rent',
      description:
          'Town centre amenities. Train station 15 min walk. Ideal for DKIT staff.',
      hostName: 'Brian L',
      hostCity: 'Dundalk',
      hostLanguage: 'English',
      hostMotherTongue: 'English',
      foodPreference: 'Non-veg',
      furnishing: 'Furnished',
      bedrooms: '2 bed',
    ),
    _listing(
      id: 'dub-rent-15',
      title: 'Family 3 bed · Dublin 16',
      price: '2400/month',
      location: 'Dublin 16',
      type: 'Rent',
      description:
          'Near schools. Safe estate. Double glazing. Long-term lease preferred.',
      hostName: 'Geetha M',
      hostCity: 'Dublin 16',
      hostLanguage: 'Kannada, English',
      hostMotherTongue: 'Kannada',
      foodPreference: 'Veg',
      furnishing: 'Semi-furnished',
      bedrooms: '3 bed',
      occupantType: 'Family',
    ),
    _listing(
      id: 'dub-rent-16',
      title: '2 bed apartment · Dundrum Luas',
      price: '2200/month',
      location: 'Dundrum, Dublin 14',
      type: 'Rent',
      description:
          'Green line 8 min. Balcony. Underground parking one space. BER B1.',
      hostName: 'Ramesh C',
      hostCity: 'Dundrum',
      hostLanguage: 'Telugu, English',
      hostMotherTongue: 'Telugu',
      foodPreference: 'Veg',
      furnishing: 'Furnished',
      bedrooms: '2 bed',
    ),
    _listing(
      id: 'dub-rent-17',
      title: '1 bed · Cherrywood · new build',
      price: '1600/month',
      location: 'Cherrywood, Dublin 18',
      type: 'Rent',
      description:
          'First occupant after renovation. Heat pump heating. Bike storage.',
      hostName: 'Olivia T',
      hostCity: 'Cherrywood',
      hostLanguage: 'English',
      hostMotherTongue: 'English',
      foodPreference: 'Non-veg',
      furnishing: 'Furnished',
      bedrooms: '1 bed',
    ),
    _listing(
      id: 'dub-rent-18',
      title: 'Budget 1 bed · Lucan village',
      price: '1350/month',
      location: 'Lucan, Dublin',
      type: 'Rent',
      description:
          'Village centre. SuperValu 3 min. Single professional or couple. No pets.',
      hostName: 'Anil W',
      hostCity: 'Lucan',
      hostLanguage: 'Marathi, English',
      hostMotherTongue: 'Marathi',
      foodPreference: 'Veg',
      furnishing: 'Unfurnished',
      bedrooms: '1 bed',
    ),
  ];

  static Map<String, dynamic> _listing({
    required String id,
    required String title,
    required String price,
    required String location,
    required String type,
    required String description,
    required String hostName,
    required String hostCity,
    required String hostLanguage,
    required String hostMotherTongue,
    required String foodPreference,
    String? roomType,
    String? furnishing,
    String? bedrooms,
    String? bathrooms,
    String? propertyCategory,
    String? shareRoomKind,
    int? currentOccupants,
    String? occupantType,
    String? bachelorPreference,
    String? preferredTenantOccupant,
    String? preferredTenantFood,
    bool? smokingAllowed,
    String? parkingType,
    List<String>? languagesSpoken,
    List<String>? lifestyleFlags,
    Map<String, dynamic>? proximityData,
    double? latitude,
    double? longitude,
  }) {
    final lowerTitle = title.toLowerCase();
    final lowerDesc = description.toLowerCase();
    final lowerRoom = (roomType ?? '').toLowerCase();

    final resolvedBedrooms = bedrooms ?? _inferBedrooms(lowerTitle, lowerDesc);
    final resolvedBathrooms = bathrooms ??
        _inferBathrooms(resolvedBedrooms, lowerTitle, lowerDesc);
    final resolvedCategory = propertyCategory ??
        _inferPropertyCategory(lowerTitle, lowerDesc, type);
    final resolvedShareKind = shareRoomKind ??
        (type == 'Share'
            ? _inferShareRoomKind(lowerTitle, lowerRoom, lowerDesc, occupantType)
            : null);
    final layoutToken = type == 'Rent'
        ? _layoutTokenFrom(resolvedBedrooms, resolvedBathrooms)
        : null;

    final resolvedParking = parkingType ?? _inferParking(lowerDesc);
    final resolvedLanguages = languagesSpoken ??
        (type == 'Share' ? _inferHouseLanguages(hostMotherTongue, hostLanguage) : null);
    final resolvedFlags = lifestyleFlags ??
        (type == 'Share' ? _inferLifestyleFlags(foodPreference, lowerDesc) : null);
    final resolvedProximity = proximityData ?? _inferProximity(lowerDesc, location);

    return {
      'id': id,
      'title': title,
      'price': price,
      'location': location,
      'type': type,
      'description': description,
      'hostName': hostName,
      'hostCity': hostCity,
      'hostLanguage': hostLanguage,
      'hostMotherTongue': hostMotherTongue,
      'foodPreference': foodPreference,
      if (roomType != null) 'room_type': roomType,
      if (furnishing != null) 'furnishing': furnishing,
      if (resolvedBedrooms != null) 'bedrooms': resolvedBedrooms,
      if (resolvedBathrooms != null) 'bathrooms': resolvedBathrooms,
      if (resolvedCategory != null) 'property_category': resolvedCategory,
      if (resolvedShareKind != null) 'share_room_kind': resolvedShareKind,
      if (layoutToken != null) 'layout_token': layoutToken,
      if (currentOccupants != null) 'current_occupants': currentOccupants,
      if (occupantType != null) 'occupantType': occupantType,
      if (bachelorPreference != null) 'bachelorPreference': bachelorPreference,
      if (preferredTenantOccupant != null)
        'preferred_tenant_occupant': preferredTenantOccupant,
      if (preferredTenantFood != null) 'preferred_tenant_food': preferredTenantFood,
      if (smokingAllowed != null) 'smoking_allowed': smokingAllowed,
      if (resolvedParking != null) 'parking_type': resolvedParking,
      if (resolvedLanguages != null && resolvedLanguages.isNotEmpty)
        'languages_spoken': resolvedLanguages,
      if (resolvedFlags != null && resolvedFlags.isNotEmpty)
        'lifestyle_flags': resolvedFlags,
      if (resolvedProximity != null) 'proximity_data': resolvedProximity,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      'listing_type': type,
      'coverImageUrl': ListingSampleImages.photoAt(
        type == 'Share' ? _sharePhotoSlot++ : _rentPhotoSlot++,
        type,
      ),
    };
  }

  static String? _inferParking(String description) {
    if (description.contains('no parking')) return 'no_parking';
    if (description.contains('parking included') ||
        description.contains('free parking') ||
        description.contains('dedicated parking')) {
      return 'free_dedicated_parking';
    }
    if (description.contains('on-street') || description.contains('paid parking')) {
      return 'paid_on_street_parking';
    }
    return null;
  }

  static List<String>? _inferHouseLanguages(
    String motherTongue,
    String hostLanguage,
  ) {
    final langs = <String>{};
    if (motherTongue.trim().isNotEmpty) langs.add(motherTongue.trim());
    for (final part in hostLanguage.split(RegExp(r'[,;]'))) {
      final lang = part.trim();
      if (lang.isNotEmpty && lang.toLowerCase() != 'english') langs.add(lang);
    }
    return langs.isEmpty ? null : langs.toList();
  }

  static List<String>? _inferLifestyleFlags(
    String foodPreference,
    String description,
  ) {
    final flags = <String>[];
    final food = foodPreference.toLowerCase();
    if (food.contains('veg') && !food.contains('non')) {
      flags.add('vegetarian_household');
    } else if (food.contains('non')) {
      flags.add('non_veg_allowed');
    }
    if (description.contains('no pet')) flags.add('no_pets');
    if (description.contains('no smoking')) flags.add('no_smoking');
    if (description.contains('quiet')) flags.add('quiet_hours_preferred');
    return flags.isEmpty ? null : flags;
  }

  static Map<String, dynamic>? _inferProximity(String description, String location) {
    final blob = '$description $location'.toLowerCase();
    if (!blob.contains('luas') && !blob.contains('green line') && !blob.contains('dart')) {
      return null;
    }
    final match = RegExp(r'(\d+)\s*min').firstMatch(blob);
    final mins = match != null ? int.tryParse(match.group(1)!) ?? 8 : 8;
    return {
      'luas_line': 'Luas',
      'nearest_transit_name': 'Luas',
      'luas_minutes': mins,
      'nearest_transit_minutes': mins,
      'transit_headline': '$mins-min to Luas',
      'has_direct_luas': true,
      'source': 'seed',
    };
  }

  static String? _inferBedrooms(String title, String description) {
    final blob = '$title $description';
    final match = RegExp(r'(\d+)\s*bed(?:room)?s?', caseSensitive: false)
        .firstMatch(blob);
    if (match != null) return '${match.group(1)} bed';
    return null;
  }

  static String? _inferBathrooms(
    String? bedrooms,
    String title,
    String description,
  ) {
    final blob = '$title $description';
    final explicit = RegExp(r'(\d+)\s*bath(?:room)?s?', caseSensitive: false)
        .firstMatch(blob);
    if (explicit != null) return '${explicit.group(1)} bath';

    final bedCount = RegExp(r'(\d+)').firstMatch(bedrooms ?? '')?.group(1);
    if (bedCount == null) return null;
    final beds = int.tryParse(bedCount) ?? 0;
    if (beds >= 3 && blob.contains('2 bath')) return '2 bath';
    return '1 bath';
  }

  static String? _inferPropertyCategory(String title, String description, String type) {
    if (type != 'Rent') return null;
    final blob = '$title $description';
    if (blob.contains('house') || blob.contains('cottage')) return 'house';
    if (blob.contains('duplex') || blob.contains('townhouse')) return 'duplex';
    if (blob.contains('apartment') ||
        blob.contains('flat') ||
        blob.contains('studio')) {
      return 'apartment';
    }
    return 'apartment';
  }

  static String? _inferShareRoomKind(
    String title,
    String roomType,
    String description,
    String? occupantType,
  ) {
    final blob = '$title $roomType $description';
    if (blob.contains('double ensuite') || blob.contains('ensuite double')) {
      return 'double_ensuite';
    }
    if (blob.contains('ensuite')) return 'ensuite';
    if (blob.contains('student') ||
        occupantType == 'Students' ||
        blob.contains('dkit')) {
      return 'student_room';
    }
    if (blob.contains('private room') &&
        (blob.contains('bathroom') || blob.contains('own bath'))) {
      return 'private_bath';
    }
    if (blob.contains('private room')) return 'private_bath';
    if (blob.contains('bed in shared') ||
        blob.contains('sharing room') ||
        blob.contains('bed space') ||
        blob.contains('shared bed')) {
      return 'bed_shared';
    }
    return null;
  }

  static String? _layoutTokenFrom(String? bedrooms, String? bathrooms) {
    final bedMatch = RegExp(r'(\d+)').firstMatch(bedrooms ?? '');
    final bathMatch = RegExp(r'(\d+)').firstMatch(bathrooms ?? '');
    if (bedMatch == null || bathMatch == null) return null;
    return '${bedMatch.group(1)}bed${bathMatch.group(1)}bath';
  }
}
