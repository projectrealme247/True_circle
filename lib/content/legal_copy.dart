/// In-app Terms of Service and Privacy Policy content for TrueCircle.
class LegalSection {
  const LegalSection({required this.heading, required this.body});

  final String heading;
  final String body;
}

abstract final class LegalCopy {
  /// Shown at the top of legal document screens.
  static const draftBanner = 'Last updated: 2 November 2026';

  static const termsTitle = 'Terms of Service';
  static const privacyTitle = 'Privacy Policy';

  static const List<LegalSection> termsSections = [
    LegalSection(
      heading: '1. Introduction and acceptance',
      body:
          'These Terms of Service (“Terms”) govern your access to and use of '
          'TrueCircle, including our website, web application, and related '
          'marketplace features (together, the “Service”).\n\n'
          'By creating an account, signing in, browsing where authentication is '
          'not required, listing a space, applying to a listing, messaging '
          'another user, arranging a viewing, or otherwise using the Service, '
          'you agree to these Terms. If you do not agree, do not use the '
          'Service.\n\n'
          'Please also read our Privacy Policy, which explains how we process '
          'personal data. By using the Service you acknowledge that policy.\n\n'
          'We may update these Terms from time to time. Material changes will be '
          'indicated by updating the “Last updated” date and, where appropriate, '
          'by notice in the Service. Continued use after changes take effect '
          'constitutes acceptance of the revised Terms, except where applicable '
          'law requires a different form of consent.',
    ),
    LegalSection(
      heading: '2. Who we are',
      body:
          'TrueCircle is an online housing marketplace based in Dublin, '
          'Ireland.\n\n'
          'Location: Dublin, Ireland\n\n'
          'Contact: projectrealme247@gmail.com',
    ),
    LegalSection(
      heading: '3. The Service',
      body:
          'TrueCircle is an online housing marketplace. We help people discover '
          'and connect around residential opportunities in two primary '
          'categories:\n\n'
          '• Shared Living — rooms or places shared with existing residents or '
          'hosts; and\n'
          '• Independent Places — entire homes or self-contained units offered '
          'for rent or occupation under arrangements agreed between users.\n\n'
          'The Service may include, among other things: public browsing, search, '
          'and filtering of listings; user accounts and profiles; listing '
          'creation and management by hosts; applications (including “Pitch Your '
          'Story” or similar); messaging between relevant users; viewing '
          'invitations and related coordination tools; verification features that '
          'affect access to certain actions; and sign-in methods such as '
          'email/password and, when enabled, third-party identity providers '
          '(including Google).\n\n'
          'TrueCircle is a platform intermediary. We do not own, rent, manage, or '
          'guarantee the properties shown. We are not a landlord, estate agent, '
          'letting agent, property manager, mortgage broker, or insurer unless we '
          'expressly say otherwise in writing.',
    ),
    LegalSection(
      heading: '4. Roles: Seekers and Hosts',
      body:
          'Seekers use the Service to find Shared Living or Independent Places, '
          'create profiles, apply, message, and arrange viewings.\n\n'
          'Hosts use the Service to publish listings, review applications, '
          'message seekers, and invite viewings.\n\n'
          'You may hold one or both roles over time, subject to product rules and '
          'verification requirements. You must not misrepresent your role or '
          'authority.\n\n'
          'Nothing in the Service creates a partnership, employment, or agency '
          'relationship between you and TrueCircle, or between you and another '
          'user, beyond any private agreement you may form outside or alongside '
          'the platform.',
    ),
    LegalSection(
      heading: '5. Accounts and eligibility',
      body:
          'You must be at least 18 years old and capable of entering a binding '
          'contract under Irish law to create an account or use authenticated '
          'features.\n\n'
          'You agree to: provide accurate, current registration information; keep '
          'your password and account secure; not share your login credentials; '
          'not create accounts for others without authority; and notify us '
          'promptly of unauthorised access.\n\n'
          'We may refuse, suspend, or close accounts where we reasonably believe '
          'there is fraud, abuse, safety risk, legal risk, or material breach of '
          'these Terms.\n\n'
          'If we enable Google or other social sign-in, you authorise us to '
          'receive basic identity information from that provider as described in '
          'our Privacy Policy. You remain responsible for the security of your '
          'linked provider account.',
    ),
    LegalSection(
      heading: '6. Profiles and preferences',
      body:
          'Profiles and preference data (for example budget, area, household '
          'type, lifestyle, commute, or language preferences) exist to support '
          'discovery and matching. They do not guarantee housing, compatibility, '
          'or acceptance by any host or seeker.\n\n'
          'You must not include unlawful, discriminatory (beyond lawful housing '
          'preferences permitted by Irish law), deceptive, or harmful content in '
          'your profile.',
    ),
    LegalSection(
      heading: '7. Listings — Shared Living and Independent Places',
      body:
          '7.1 Host responsibilities\n\n'
          'If you publish a listing, you represent and warrant that: you have all '
          'rights and authority needed to offer the space; listing details (rent '
          'or contribution, availability, location description, amenities, house '
          'rules, photos, and media) are accurate and not misleading; photos and '
          'videos reasonably represent the current space; you will update or '
          'unpublish the listing when it is no longer available; and you will '
          'comply with applicable housing, tenancy, planning, tax, and consumer '
          'laws.\n\n'
          '7.2 Category accuracy\n\n'
          'You must place listings in the correct category: Shared Living where '
          'the arrangement involves sharing with others; Independent Places where '
          'the offer is for an entire or self-contained place as represented. '
          'Mis-categorisation, duplicate listings for the same offer, or “bait” '
          'listings are prohibited.\n\n'
          '7.3 Our role regarding listings\n\n'
          'We may, but are not obliged to, review, edit, refuse, hide, or remove '
          'listings that appear inaccurate, unlawful, unsafe, or contrary to '
          'these Terms. Publication does not mean endorsement.\n\n'
          'Exact address visibility may be limited for privacy or safety. Seekers '
          'should confirm critical details directly with hosts before relying on '
          'them.',
    ),
    LegalSection(
      heading: '8. Applications',
      body:
          'Applications (including pitches or personal introductions) allow '
          'seekers to express interest in a listing.\n\n'
          'By submitting an application you agree that: your statements are '
          'truthful to the best of your knowledge; you will not spam hosts or '
          'submit abusive content; and a host has no obligation to respond, '
          'shortlist, or accept you.\n\n'
          'Hosts agree to handle applications in good faith and not use applicant '
          'data for unrelated marketing or unlawful discrimination.\n\n'
          'TrueCircle does not guarantee outcomes of any application and is not a '
          'party to any tenancy or occupancy agreement that may follow.',
    ),
    LegalSection(
      heading: '9. Messaging',
      body:
          'Messaging is provided so relevant users can communicate about '
          'listings, applications, and arrangements.\n\n'
          'You agree to use messaging lawfully and respectfully. You must not: '
          'harass, threaten, or exploit others; send spam, scams, or malware; '
          'share another person’s personal data without a lawful basis; attempt '
          'to bypass safety or verification controls in bad faith; or use '
          'messaging for illegal activity.\n\n'
          'We may limit, monitor where lawful and necessary for safety/abuse '
          'prevention, or disable messaging features. Message content may be '
          'processed as described in the Privacy Policy.\n\n'
          'TrueCircle is not responsible for statements made by users in '
          'messages.',
    ),
    LegalSection(
      heading: '10. Viewing invitations',
      body:
          'Hosts may invite seekers to view a property, and seekers may accept, '
          'decline, or propose alternatives using tools we provide (or by '
          'coordinating in messages).\n\n'
          'Viewings are arranged between users. TrueCircle: does not conduct, '
          'supervise, or insure viewings; does not verify that a viewing will '
          'occur as scheduled; and is not liable for incidents at a viewing '
          'location, except to the extent liability cannot be excluded under '
          'Irish law.\n\n'
          'Users should take sensible safety precautions (identity checks, '
          'bringing another person where appropriate, meeting in agreed '
          'conditions, and similar).',
    ),
    LegalSection(
      heading: '11. Verification and access controls',
      body:
          'Certain actions (for example contacting a host, applying, or '
          'messaging) may require verification. Methods may include, depending on '
          'product rules and your situation: university or student-related email '
          'verification; LinkedIn or employment-related verification; and other '
          'document or provider-based checks we offer from time to time.\n\n'
          'Verification is used to support trust and access control on the '
          'marketplace. It is not: a credit check performed by TrueCircle as a '
          'lender; a guarantee of character, income, or tenancy suitability; or '
          'legal advice.\n\n'
          'You must not falsify verification information. We may revoke verified '
          'status if we reasonably believe it was obtained improperly.\n\n'
          '“Verified User” (or similar labels) indicate that stated checks were '
          'completed according to our then-current rules; they do not replace '
          'your own diligence.',
    ),
    LegalSection(
      heading: '12. Acceptable use',
      body:
          'You must not use the Service to: break Irish or applicable EU law; '
          'discriminate unlawfully in housing offers or applications; scrape, '
          'harvest, or bulk-export data without our written permission; reverse '
          'engineer or disrupt the Service; impersonate others or create fake '
          'listings or applications; infringe intellectual property or privacy '
          'rights; post illegal, hateful, or sexually exploitative content; or '
          'attempt unauthorised access to systems or other users’ accounts.\n\n'
          'We may investigate suspected breaches and take action including '
          'content removal, feature limits, and account suspension or '
          'termination.',
    ),
    LegalSection(
      heading: '13. User content',
      body:
          'You retain ownership of content you submit (profiles, listings, '
          'applications, messages, photos, and similar) (“User Content”).\n\n'
          'You grant TrueCircle a worldwide, non-exclusive, royalty-free licence '
          'to host, store, reproduce, adapt for display, and communicate User '
          'Content as needed to operate, improve, secure, and promote the Service '
          '(for example showing your listing in search results). This licence '
          'ends when you remove content from the Service, except for reasonable '
          'residual copies in backups or where retention is required by law or '
          'for dispute resolution.\n\n'
          'You are responsible for User Content and confirm you have rights to '
          'grant this licence.',
    ),
    LegalSection(
      heading: '14. TrueCircle intellectual property',
      body:
          'The Service, branding, software, design, and documentation are owned '
          'by TrueCircle or its licensors. You receive a limited, revocable, '
          'non-transferable right to use the Service for its intended purpose. '
          'You may not copy, modify, or commercially exploit our IP except as '
          'allowed by law or written permission.',
    ),
    LegalSection(
      heading: '15. Fees',
      body:
          'Unless we clearly state otherwise in the Service, core marketplace use '
          'may be offered without charge. We reserve the right to introduce fees '
          'for certain features in the future. If we do, we will describe the '
          'fees before you are charged and obtain any consent required by law.\n\n'
          'You are responsible for any taxes applicable to your own housing '
          'arrangements with other users.',
    ),
    LegalSection(
      heading: '16. No tenancy; no housing guarantee',
      body:
          'TrueCircle does not grant tenancies, licences, or occupancy rights. '
          'Any agreement for rent, contribution, deposit, keys, or move-in is '
          'solely between the users involved (and any third parties they '
          'involve).\n\n'
          'We do not guarantee that you will find a place, fill a room, receive '
          'replies, or complete a successful move.',
    ),
    LegalSection(
      heading: '17. Disputes between users',
      body:
          'If you have a dispute with another user, you should attempt to resolve '
          'it directly. We may, at our discretion, offer limited assistance (for '
          'example account or safety review) but are not obliged to mediate or '
          'adjudicate private housing disputes.',
    ),
    LegalSection(
      heading: '18. Suspension and termination',
      body:
          'You may stop using the Service and request account closure subject to '
          'our Privacy Policy and any lawful retention needs.\n\n'
          'We may suspend or terminate access immediately where we reasonably '
          'believe it is necessary to protect users, the Service, or to address '
          'breach, fraud, or legal risk.\n\n'
          'Sections that by nature should survive (including IP, disclaimers, '
          'liability limits, indemnity, and governing law) survive termination.',
    ),
    LegalSection(
      heading: '19. Disclaimers',
      body:
          'To the fullest extent permitted by Irish law, the Service is provided '
          'on an “as is” and “as available” basis. We do not warrant '
          'uninterrupted or error-free operation, or that listings, profiles, '
          'verification badges, or messages are accurate or complete.\n\n'
          'We are not responsible for third-party sites or services you access '
          'through the Service (including Google or LinkedIn sign-in or '
          'verification flows), except as required by law.\n\n'
          'Nothing in these Terms excludes or limits liability for death or '
          'personal injury caused by negligence, fraud, or any other liability '
          'that cannot be limited under Irish law. If you are a consumer, your '
          'mandatory statutory rights remain unaffected.',
    ),
    LegalSection(
      heading: '20. Limitation of liability',
      body:
          'Subject to Section 19, TrueCircle’s total aggregate liability arising '
          'out of or in connection with the Service or these Terms in any '
          'twelve-month period is limited to the greater of (a) EUR 100 and (b) '
          'the total fees you paid to TrueCircle for the Service in that period '
          '(if any).\n\n'
          'We are not liable for indirect or consequential loss, loss of profit, '
          'loss of opportunity, or loss of data, except where such exclusion is '
          'not permitted by law.',
    ),
    LegalSection(
      heading: '21. Indemnity',
      body:
          'You agree to indemnify TrueCircle against reasonable losses, costs, '
          'and expenses arising from your User Content, your listings or '
          'applications, your misuse of the Service, or your breach of these '
          'Terms, except to the extent caused by our wilful misconduct or '
          'negligence as finally determined.',
    ),
    LegalSection(
      heading: '22. Privacy',
      body:
          'Our processing of personal data is described in the Privacy Policy. '
          'Where we rely on consent for a specific processing activity, you may '
          'withdraw it as explained there, without affecting the lawfulness of '
          'prior processing.',
    ),
    LegalSection(
      heading: '23. Changes to the Service',
      body:
          'We may modify, suspend, or discontinue features. We will try to avoid '
          'unnecessary disruption but do not guarantee that any particular '
          'feature will remain available.',
    ),
    LegalSection(
      heading: '24. Governing law and jurisdiction',
      body:
          'These Terms and any dispute arising out of or in connection with them '
          'or the Service are governed by the laws of Ireland.\n\n'
          'The courts of Ireland have exclusive jurisdiction, without prejudice '
          'to mandatory consumer protections that allow you to bring proceedings '
          'in your country of residence where applicable.',
    ),
    LegalSection(
      heading: '25. General',
      body:
          'If any provision is held unenforceable, the remainder continues in '
          'effect. Our failure to enforce a provision is not a waiver. You may '
          'not assign these Terms without our consent; we may assign them in '
          'connection with a reorganisation or sale. These Terms are the entire '
          'agreement between you and us regarding the Service, superseding prior '
          'conflicting terms on the same subject.',
    ),
    LegalSection(
      heading: '26. Contact',
      body:
          'Questions about these Terms: projectrealme247@gmail.com',
    ),
  ];

  static const List<LegalSection> privacySections = [
    LegalSection(
      heading: '1. Introduction',
      body:
          'This Privacy Policy explains how TrueCircle (“we”, “us”, “our”) '
          'collects, uses, shares, and protects personal data when you use our '
          'marketplace Service (website and web application), including browsing, '
          'accounts, listings, applications, messaging, viewing invitations, and '
          'verification.\n\n'
          'We process personal data in accordance with the EU General Data '
          'Protection Regulation (GDPR) and applicable Irish data protection law.',
    ),
    LegalSection(
      heading: '2. Data Controller',
      body:
          'TrueCircle\n\n'
          'Location: Dublin, Ireland\n\n'
          'Privacy enquiries: projectrealme247@gmail.com\n\n'
          'Data Protection Officer: Not currently appointed. Please contact '
          'projectrealme247@gmail.com for privacy-related queries.',
    ),
    LegalSection(
      heading: '3. Scope',
      body:
          'This policy applies to personal data processed through TrueCircle’s '
          'Service for Shared Living and Independent Places marketplace activity. '
          'It does not cover third-party websites or apps that we do not control '
          '(for example Google or LinkedIn), which have their own policies.',
    ),
    LegalSection(
      heading: '4. Personal data we collect',
      body:
          'Depending on how you use the Service, we may process:\n\n'
          '4.1 Account and authentication data\n'
          'Email address, password credentials (stored hashed/secured by our auth '
          'provider), account identifiers, sign-in timestamps, and, if you use '
          'Google or similar OAuth when enabled, basic profile identifiers and '
          'email supplied by that provider.\n\n'
          '4.2 Profile and preference data\n'
          'Name, role (seeker/host), household or occupant type, location or area '
          'preferences, budget ranges, lifestyle and language preferences, commute '
          'preferences, and similar matching inputs you provide.\n\n'
          '4.3 Listing data\n'
          'Listing descriptions, rent or contribution information, availability, '
          'amenities, house rules, photos/videos, approximate or precise location '
          'data you choose to provide, and host-related listing metadata.\n\n'
          '4.4 Applications and pitches\n'
          'Application content, personal introductions, answers you submit, and '
          'related status (submitted, reviewed, and similar).\n\n'
          '4.5 Messaging data\n'
          'Message content, participants, timestamps, and related thread metadata '
          'for application or listing conversations.\n\n'
          '4.6 Viewing-related data\n'
          'Viewing invitations, proposed times, acceptance/decline status, and '
          'related coordination notes exchanged through the Service.\n\n'
          '4.7 Verification data\n'
          'Verification method and status (for example university email verified, '
          'LinkedIn connected, employment-related verification). Where a flow is '
          'designed for limited retention of source documents, we aim to keep '
          'status and necessary confirmations rather than unnecessary copies of '
          'sensitive documents, subject to the specific flow’s design and legal '
          'needs.\n\n'
          '4.8 Technical and usage data\n'
          'IP address, device/browser type, approximate location derived from '
          'technical signals where applicable, logs, diagnostics, and interaction '
          'data needed for security and reliability.\n\n'
          '4.9 Support data\n'
          'Information you send when contacting support.\n\n'
          'We do not require you to provide more data than needed for the features '
          'you use. Public browsing may involve limited technical data only.',
    ),
    LegalSection(
      heading: '5. Sources of data',
      body:
          '• You, when you register, complete a profile, list a space, apply, '
          'message, or verify;\n'
          '• Other users, when they interact with you (for example a host viewing '
          'your application);\n'
          '• Identity / verification providers, such as Google (if used for '
          'sign-in), LinkedIn (if used for verification), email OTP providers, or '
          'similar;\n'
          '• Service providers processing data on our instructions (hosting, '
          'authentication, analytics if used, email delivery).',
    ),
    LegalSection(
      heading: '6. Purposes and legal bases',
      body:
          'We process personal data for the following purposes and GDPR legal '
          'bases (Article 6):\n\n'
          '• Provide the Service (account, listings, search, applications, '
          'messaging, viewings): contract (Art. 6(1)(b)) and/or legitimate '
          'interests (Art. 6(1)(f)) for core platform operation.\n'
          '• Matching and discovery (showing relevant Shared Living / Independent '
          'Place results): legitimate interests; contract where tied to requested '
          'features.\n'
          '• Verification and access control (gating contact/apply/message behind '
          'verification): legitimate interests (safety, fraud prevention, '
          'marketplace integrity); consent where a flow expressly relies on '
          'consent.\n'
          '• Security and abuse prevention: legitimate interests; legal obligation '
          'where applicable.\n'
          '• Communications (service messages, security alerts): contract / '
          'legitimate interests; consent for optional marketing if introduced.\n'
          '• Improvement (aggregated or limited analytics): legitimate interests.\n'
          '• Legal compliance: legal obligation (Art. 6(1)(c)) and/or legitimate '
          'interests.\n\n'
          'Where we rely on legitimate interests, we balance those interests against '
          'your rights. You may object as described in Section 12.\n\n'
          'Where we rely on consent, you may withdraw it at any time without '
          'affecting prior lawful processing.\n\n'
          'Special category data: We do not seek to collect special category data '
          'as a core requirement. Please avoid submitting unnecessary sensitive '
          'data in free-text fields. If a verification flow processes limited '
          'sensitive-related information, we will identify an Article 9 condition '
          'where required.',
    ),
    LegalSection(
      heading: '7. How we use data in the marketplace',
      body:
          'We use personal data to: operate accounts and authentication (including '
          'future Google OAuth sign-in); publish and display listings you create; '
          'enable seekers to discover Shared Living and Independent Places; enable '
          'applications and host review workflows; enable messaging between '
          'permitted participants; enable viewing invitations and scheduling '
          'coordination; apply verification rules for certain actions; provide '
          'customer support; maintain security, prevent fraud, and enforce our '
          'Terms; and meet legal obligations.\n\n'
          'We do not sell your personal data.',
    ),
    LegalSection(
      heading: '8. Sharing of personal data',
      body:
          '8.1 Other users\n'
          'Marketplace use necessarily involves sharing relevant information with '
          'other users. For example: hosts may see seeker profile and application '
          'information when you apply; seekers may see host and listing '
          'information; participants in a message thread can see messages in that '
          'thread; viewing invitation details are visible to the invited parties. '
          'You should only share information in applications and messages that you '
          'are comfortable disclosing to the other party.\n\n'
          '8.2 Service providers (processors)\n'
          'We use processors such as cloud hosting, database, and authentication '
          'providers, email delivery, and similar vendors. They process data on '
          'our instructions under appropriate contracts.\n\n'
          '8.3 Identity providers\n'
          'If you sign in with Google or connect LinkedIn (or similar), those '
          'providers process data under their policies. We receive only what is '
          'needed for sign-in or verification.\n\n'
          '8.4 Legal and safety\n'
          'We may disclose data if required by law, court order, or regulators, or '
          'where necessary to protect rights, safety, and security of users or '
          'TrueCircle.\n\n'
          '8.5 Business transfers\n'
          'If we undergo a merger, acquisition, or asset transfer, personal data '
          'may be transferred under appropriate safeguards and notice where '
          'required.',
    ),
    LegalSection(
      heading: '9. International transfers',
      body:
          'Where personal data is transferred outside the European Economic Area, '
          'we ensure appropriate safeguards (such as European Commission adequacy '
          'decisions or Standard Contractual Clauses) unless a GDPR derogation '
          'applies. Details of transfer mechanisms for key processors are available '
          'on request.',
    ),
    LegalSection(
      heading: '10. Retention',
      body:
          'We retain personal data only as long as needed for the purposes above, '
          'including: active account and marketplace operation; security and fraud '
          'prevention; dispute handling and legal claims (often aligned with '
          'relevant Irish limitation periods); and legal obligations.\n\n'
          'When data is no longer required, we delete or anonymise it where '
          'reasonably practicable. Backup systems may retain residual copies for a '
          'limited period.\n\n'
          'Verification source documents, if momentarily processed, are retained '
          'only as required by the specific flow; status flags may persist longer '
          'for access control and audit integrity.',
    ),
    LegalSection(
      heading: '11. Security',
      body:
          'We implement appropriate technical and organisational measures, '
          'including access controls, encrypted transport where applicable, and '
          'provider-level security practices. No method of transmission or storage '
          'is completely secure. Please use a strong unique password and protect '
          'your devices and linked OAuth accounts.',
    ),
    LegalSection(
      heading: '12. Your rights under GDPR',
      body:
          'You have the right, subject to GDPR conditions, to: access your '
          'personal data; rectify inaccurate data; erase data in certain '
          'circumstances; restrict processing in certain circumstances; data '
          'portability where processing is based on consent or contract and '
          'carried out by automated means; object to processing based on '
          'legitimate interests; withdraw consent where processing is '
          'consent-based; and lodge a complaint with the Data Protection '
          'Commission (Ireland) (or your local supervisory authority if you live '
          'elsewhere in the EEA/UK as applicable).\n\n'
          'To exercise rights, contact projectrealme247@gmail.com. We may need to '
          'verify your identity before fulfilling a request.\n\n'
          'You also have the right not to be subject to a decision based solely on '
          'automated processing that produces legal or similarly significant '
          'effects concerning you. TrueCircle’s matching and ranking tools are '
          'designed to support discovery; material housing decisions are made by '
          'users. If this changes, we will update this policy.',
    ),
    LegalSection(
      heading: '13. Children',
      body:
          'The Service is directed at adults aged 18+. We do not knowingly collect '
          'personal data from children. If you believe we have received such data, '
          'contact us and we will take appropriate steps.',
    ),
    LegalSection(
      heading: '14. Cookies and similar technologies',
      body:
          'We may use essential cookies or local storage required for '
          'authentication and security. If we use non-essential analytics or '
          'advertising cookies in future, we will provide a Cookie Policy and '
          'obtain consent where required. This Privacy Policy is not a full Cookie '
          'Policy.',
    ),
    LegalSection(
      heading: '15. Automated tools and profiling',
      body:
          'We may use limited profiling (for example preference-based ordering of '
          'listings) to make the Service useful. This is not intended to produce '
          'legal or similarly significant effects solely by automated means '
          'without human involvement by the relevant host or seeker.',
    ),
    LegalSection(
      heading: '16. Changes to this policy',
      body:
          'We may update this Privacy Policy from time to time. We will revise the '
          '“Last updated” date and, for material changes, provide additional notice '
          'where appropriate.',
    ),
    LegalSection(
      heading: '17. Contact',
      body:
          'Privacy questions and GDPR requests: projectrealme247@gmail.com\n\n'
          'Location: Dublin, Ireland\n\n'
          'Supervisory authority: Data Protection Commission, Ireland — '
          'https://www.dataprotection.ie/',
    ),
  ];
}
