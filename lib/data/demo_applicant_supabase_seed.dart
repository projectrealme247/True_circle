abstract final class DemoApplicantSupabaseSeed {
  static const listingId = 'mock-listing-dublin-ranelagh-shared';

  static const trustProfiles = <Map<String, dynamic>>[
    {
      'user_id': 'dublin-mock-user-mark',
      'full_name': "Mark O'Connor",
      'trust_tier': 'Sound',
      'trust_stage': 3,
      'identity_trust_tier': 'Corporate_Ready',
    },
    {
      'user_id': 'dublin-mock-user-niamh',
      'full_name': 'Niamh Byrne',
      'trust_tier': 'Sound',
      'trust_stage': 3,
      'identity_trust_tier': 'Corporate_Ready',
    },
    {
      'user_id': 'dublin-mock-user-luke',
      'full_name': 'Luke Gallagher',
      'trust_tier': 'Sound',
      'trust_stage': 3,
      'identity_trust_tier': 'Corporate_Ready',
    },
    {
      'user_id': 'dublin-mock-user-chloe',
      'full_name': 'Chloe Dubois',
      'trust_tier': 'Grand',
      'trust_stage': 2,
      'identity_trust_tier': 'Education_Verified',
    },
    {
      'user_id': 'dublin-mock-user-sofia',
      'full_name': 'Sofia Rossi',
      'trust_tier': 'Grand',
      'trust_stage': 2,
      'identity_trust_tier': 'Education_Verified',
    },
    {
      'user_id': 'dublin-mock-user-tomasz',
      'full_name': 'Tomasz Kowalski',
      'trust_tier': 'Grand',
      'trust_stage': 2,
      'identity_trust_tier': 'Education_Verified',
    },
    {
      'user_id': 'dublin-mock-user-aarav',
      'full_name': 'Aarav Mehta',
      'trust_tier': 'Just Landed',
      'trust_stage': 1,
      'identity_trust_tier': 'Casual_Browser',
    },
    {
      'user_id': 'dublin-mock-user-linh',
      'full_name': 'Linh Nguyen',
      'trust_tier': 'Just Landed',
      'trust_stage': 1,
      'identity_trust_tier': 'Casual_Browser',
    },
    {
      'user_id': 'dublin-mock-user-samir',
      'full_name': 'Samir Khan',
      'trust_tier': 'Just Landed',
      'trust_stage': 1,
      'identity_trust_tier': 'Casual_Browser',
    },
  ];

  static const listingApplications = <Map<String, dynamic>>[
    {
      'id': 'dublin-mock-app-mark',
      'listing_id': listingId,
      'applicant_user_id': 'dublin-mock-user-mark',
      'status': 'pending',
      'compatibility_score': 91,
    },
    {
      'id': 'dublin-mock-app-niamh',
      'listing_id': listingId,
      'applicant_user_id': 'dublin-mock-user-niamh',
      'status': 'pending',
      'compatibility_score': 88,
    },
    {
      'id': 'dublin-mock-app-luke',
      'listing_id': listingId,
      'applicant_user_id': 'dublin-mock-user-luke',
      'status': 'pending',
      'compatibility_score': 86,
    },
    {
      'id': 'dublin-mock-app-chloe',
      'listing_id': listingId,
      'applicant_user_id': 'dublin-mock-user-chloe',
      'status': 'viewing_scheduled',
      'compatibility_score': 82,
    },
    {
      'id': 'dublin-mock-app-sofia',
      'listing_id': listingId,
      'applicant_user_id': 'dublin-mock-user-sofia',
      'status': 'viewing_scheduled',
      'compatibility_score': 80,
    },
    {
      'id': 'dublin-mock-app-tomasz',
      'listing_id': listingId,
      'applicant_user_id': 'dublin-mock-user-tomasz',
      'status': 'pending',
      'compatibility_score': 78,
    },
    {
      'id': 'dublin-mock-app-aarav',
      'listing_id': listingId,
      'applicant_user_id': 'dublin-mock-user-aarav',
      'status': 'pending',
      'compatibility_score': 76,
    },
    {
      'id': 'dublin-mock-app-linh',
      'listing_id': listingId,
      'applicant_user_id': 'dublin-mock-user-linh',
      'status': 'pending',
      'compatibility_score': 73,
    },
    {
      'id': 'dublin-mock-app-samir',
      'listing_id': listingId,
      'applicant_user_id': 'dublin-mock-user-samir',
      'status': 'pending',
      'compatibility_score': 70,
    },
  ];
}
