/// Artisan Lane community guidelines, shown in the app's Community Guidelines
/// screen and summarised in the one-time acceptance sheet. The website's
/// /community-guidelines page carries the same rules.
library;

import '../buyer/utils/help_support_contact.dart';

const communityGuidelinesRoute = '/community-guidelines';
const communityGuidelinesLastUpdated = 'October 2026';

/// Short rules for the acceptance sheet.
const communityGuidelinesSummary = <String>[
  'No hate speech, slurs or abuse of anyone for who they are.',
  'No harassment, bullying, threats or unwanted contact.',
  'No sexual or explicit content.',
  'No scams, fake listings, off-app payment requests or spam.',
  "No stolen designs, photos or other people's intellectual property.",
];

const communityGuidelinesSections = <Map<String, String>>[
  {
    'heading': 'Zero tolerance',
    'body':
        'Artisan Lane has no tolerance for objectionable content or abusive '
        'users. These guidelines apply to everything you post or send: shop '
        'names and bios, posts, stories, polls, comments, reviews, chat '
        'messages and your profile name. By posting or messaging you agree to '
        'follow them and our Terms of Service.',
  },
  {
    'heading': '1. Respect everyone',
    'body':
        'No hate speech, slurs, or content that attacks or demeans people '
        'because of race, ethnicity, nationality, religion, gender, sexual '
        'orientation, disability or any other part of who they are.',
  },
  {
    'heading': '2. No harassment or threats',
    'body':
        'Do not bully, intimidate, threaten, stalk or repeatedly contact '
        'someone who has not asked to hear from you. Do not share anyone\'s '
        'personal information without their permission.',
  },
  {
    'heading': '3. No sexual or explicit content',
    'body':
        'Nudity, pornography, sexually explicit language and sexual content '
        'involving minors are not allowed anywhere on Artisan Lane. Content '
        'that sexualises minors is reported to the authorities.',
  },
  {
    'heading': '4. No scams or spam',
    'body':
        'No fake listings, misleading claims, phishing links, requests to pay '
        'outside Artisan Lane, or repetitive promotional messages. Keep orders '
        'and payments on the platform so escrow can protect you.',
  },
  {
    'heading': '5. Respect intellectual property',
    'body':
        'Only post photos, designs and words you made or have permission to '
        'use. Copying another maker\'s work or listing counterfeit goods is '
        'not allowed.',
  },
  {
    'heading': '6. Honest reviews',
    'body':
        'Reviews should describe your genuine experience with an order. Do not '
        'post fake, paid or retaliatory reviews, or use a review to harass a '
        'maker or buyer.',
  },
  {
    'heading': 'How we keep Artisan Lane safe',
    'body':
        'Text with slurs, explicit or severely abusive language is blocked '
        'before it is posted. You can report any post, story, comment, review, '
        'message or maker from its menu, and block anyone so they can no '
        'longer comment on your posts or message you. Our team reviews reports '
        'within 24 hours, removes content that breaks these rules, and '
        'suspends or removes the accounts of people who post it.',
  },
  {
    'heading': 'Contact us',
    'body':
        'To report a problem or ask about these guidelines, email '
        '$helpSupportEmail or WhatsApp $helpSupportWhatsappDisplay. You can '
        'also find these options under Help & Support.',
  },
];
