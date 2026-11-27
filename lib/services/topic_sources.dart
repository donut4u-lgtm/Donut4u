/// One place to control what each topic bot looks for.
/// To add a keyword, put "+OR+yourword" inside that topic's search line.
/// (use + instead of spaces)

class SourceFeed {
  final String name;
  final String url;
  const SourceFeed(this.name, this.url);
}

// Google News search = anything found on the internet in the last 24 hours.
const String _gn = 'https://news.google.com/rss/search?q=';
const String _tl = '+when:1d&hl=fil&gl=PH&ceid=PH:fil'; // Tagalog edition
const String _en = '+when:1d&hl=en-PH&gl=PH&ceid=PH:en'; // English edition

// ---- The wide searches, one per topic ----

const String _qViral =
    'viral+OR+kumakalat+OR+netizens+OR+TikTok+OR+usap-usapan+OR+pinag-usapan+OR+trending+video';

const String _qHaha =
    'nakakatawa+OR+meme+OR+funny+OR+prank+OR+biro+OR+hugot+OR+comedy+OR+bloopers+OR+jokes';

const String _qUso =
    'trending+OR+uso+OR+challenge+OR+TikTok+OR+fashion+OR+gimik+OR+craze+OR+fad';

const String _qBalita =
    'balita+OR+breaking+news+OR+Philippines+news+OR+gobyerno+OR+bagyo+OR+presyo+OR+ekonomiya+OR+pulis';

const String _qChika =
    'showbiz+OR+chika+OR+celebrity+OR+artista+OR+loveteam+OR+intriga+OR+chismis+OR+influencer';

const String _qPagkain =
    'pagkain+OR+food+OR+recipe+OR+restaurant+OR+street+food+OR+lutuin+OR+kainan+OR+ulam+OR+kape';

const String _qLibangan =
    'pelikula+OR+teleserye+OR+movie+OR+series+OR+musika+OR+concert+OR+OPM+OR+K-pop+OR+Netflix+OR+anime+OR+video+games';

const String _qSports =
    'sports+OR+basketball+OR+NBA+OR+PBA+OR+Gilas+OR+volleyball+OR+boxing+OR+football+OR+soccer+OR+tennis+OR+UAAP+OR+NCAA+OR+Olympics+OR+MMA+OR+badminton+OR+laro+OR+palakasan';

const String _qTekno =
    'teknolohiya+OR+technology+OR+gadget+OR+smartphone+OR+app+OR+AI+OR+gaming+OR+Android+OR+internet+OR+cybersecurity';

const String _qPagibig =
    'pag-ibig+OR+love+OR+relationship+OR+dating+OR+kasal+OR+hugot+OR+payo+OR+breakup+OR+romance';

const String _qLokal =
    'lokal+OR+probinsya+OR+barangay+OR+lungsod+OR+Cebu+OR+Davao+OR+Mindanao+OR+Visayas+OR+Luzon+OR+LGU';

// ---- What each topic bot reads ----

const Map<String, List<SourceFeed>> kTopicSources = {
  'viral': [
    SourceFeed('Google News', '$_gn$_qViral$_tl'),
    SourceFeed('Google News', '$_gn$_qViral$_en'),
  ],
  'haha': [
    SourceFeed('Google News', '$_gn$_qHaha$_tl'),
    SourceFeed('Google News', '$_gn$_qHaha$_en'),
  ],
  'uso': [
    SourceFeed('Google News', '$_gn$_qUso$_tl'),
    SourceFeed('Google News', '$_gn$_qUso$_en'),
  ],
  'balita': [
    SourceFeed('Inquirer', 'https://newsinfo.inquirer.net/feed'),
    SourceFeed('GMA News', 'https://data.gmanetwork.com/gno/rss/news/feed.xml'),
    SourceFeed('Philstar', 'https://www.philstar.com/rss/headlines'),
    SourceFeed('Google News', '$_gn$_qBalita$_tl'),
    SourceFeed('Google News', '$_gn$_qBalita$_en'),
  ],
  'chika': [
    SourceFeed('GMA Showbiz', 'https://data.gmanetwork.com/gno/rss/showbiz/feed.xml'),
    SourceFeed('Google News', '$_gn$_qChika$_tl'),
    SourceFeed('Google News', '$_gn$_qChika$_en'),
  ],
  'pagkain': [
    SourceFeed('Google News', '$_gn$_qPagkain$_tl'),
    SourceFeed('Google News', '$_gn$_qPagkain$_en'),
  ],
  'libangan': [
    SourceFeed('Philstar Entertainment', 'https://www.philstar.com/rss/entertainment'),
    SourceFeed('Inquirer Entertainment', 'https://entertainment.inquirer.net/feed'),
    SourceFeed('Google News', '$_gn$_qLibangan$_tl'),
    SourceFeed('Google News', '$_gn$_qLibangan$_en'),
  ],
  'sports': [
    SourceFeed('Inquirer Sports', 'https://sports.inquirer.net/feed'),
    SourceFeed('GMA Sports', 'https://data.gmanetwork.com/gno/rss/sports/feed.xml'),
    SourceFeed('Philstar Sports', 'https://www.philstar.com/rss/sports'),
    SourceFeed('Google News', '$_gn$_qSports$_tl'),
    SourceFeed('Google News', '$_gn$_qSports$_en'),
  ],
  'tekno': [
    SourceFeed('GMA SciTech', 'https://data.gmanetwork.com/gno/rss/scitech/feed.xml'),
    SourceFeed('Inquirer Technology', 'https://technology.inquirer.net/feed'),
    SourceFeed('Google News', '$_gn$_qTekno$_tl'),
    SourceFeed('Google News', '$_gn$_qTekno$_en'),
  ],
  'pagibig': [
    SourceFeed('Philstar Lifestyle', 'https://www.philstar.com/rss/lifestyle'),
    SourceFeed('GMA Lifestyle', 'https://data.gmanetwork.com/gno/rss/lifestyle/feed.xml'),
    SourceFeed('Google News', '$_gn$_qPagibig$_tl'),
    SourceFeed('Google News', '$_gn$_qPagibig$_en'),
  ],
  'lokal': [
    SourceFeed('Philstar Nation', 'https://www.philstar.com/rss/nation'),
    SourceFeed('GMA Regions', 'https://data.gmanetwork.com/gno/rss/news/regions/feed.xml'),
    SourceFeed('Google News', '$_gn$_qLokal$_tl'),
    SourceFeed('Google News', '$_gn$_qLokal$_en'),
  ],
};
