import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jwsongbook/data/database/app_database.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'songs_repository.g.dart';

@Riverpod(keepAlive: true)
SongsDao songsDao(Ref ref) => ref.watch(appDatabaseProvider).songsDao;

@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) => AppDatabase();

class SongsRepository {
  SongsRepository(this._dao);

  final SongsDao _dao;

  Stream<List<Song>> watchAll() => _dao.watchAll();

  Stream<List<Song>> watchSearch(String query) => _dao.watchSearch(query);

  Stream<List<Song>> watchFavorites() => _dao.watchFavorites();

  Stream<List<Song>> watchRecentlyPlayed() => _dao.watchRecentlyPlayed();

  Future<List<Song>> getAllSongs() => _dao.getAll();

  Future<Song?> getByNumber(int number) => _dao.getByNumber(number);

  Future<void> toggleFavorite(Song song) =>
      _dao.toggleFavorite(song.id, value: !song.isFavorited);

  Future<void> markPlayed(Song song) => _dao.markPlayed(song.id);

  Future<void> markDownloaded(Song song, {required String audioFilePath}) =>
      _dao.markDownloaded(song.id, audioFilePath: audioFilePath);

  /// Seed the database with all 162 song titles.
  /// Call once on first launch.  No-op if data already exists.
  Future<void> seedIfEmpty() async {
    final existing = await _dao.getAll();
    if (existing.isNotEmpty) return;
    await _dao.upsertAll(_kSeedSongs);
  }
}

@riverpod
SongsRepository songsRepository(Ref ref) =>
    SongsRepository(ref.watch(songsDaoProvider));

// ── Seed data ─────────────────────────────────────────────────────────────────
// All 162 titles from the Kingdom Songs songbook.
// durationMs is left null here — KS-Sync will fill it in once audio is analysed.
final List<SongsCompanion> _kSeedSongs = [
  SongsCompanion.insert(number: 1, title: "Jehovah's Attributes"),
  SongsCompanion.insert(number: 2, title: 'Jehovah Is Your Name'),
  SongsCompanion.insert(
    number: 3,
    title: 'Our Strength, Our Hope, Our Confidence',
  ),
  SongsCompanion.insert(number: 4, title: '"Jehovah Is My Shepherd"'),
  SongsCompanion.insert(number: 5, title: "God's Wondrous Works"),
  SongsCompanion.insert(number: 6, title: "The Heavens Declare God's Glory"),
  SongsCompanion.insert(number: 7, title: 'Jehovah, Our Strength'),
  SongsCompanion.insert(number: 8, title: 'Jehovah Is Our Refuge'),
  SongsCompanion.insert(number: 9, title: 'Jehovah Is Our King!'),
  SongsCompanion.insert(number: 10, title: 'Praise Jehovah Our God!'),
  SongsCompanion.insert(number: 11, title: 'Creation Praises God'),
  SongsCompanion.insert(number: 12, title: 'Great God, Jehovah'),
  SongsCompanion.insert(number: 13, title: 'Christ, Our Model'),
  SongsCompanion.insert(number: 14, title: "Praising Earth's New King"),
  SongsCompanion.insert(number: 15, title: "Praise Jehovah's Firstborn!"),
  SongsCompanion.insert(
    number: 16,
    title: 'Praise Jah for His Son, the Anointed',
  ),
  SongsCompanion.insert(number: 17, title: '"I Want To"'),
  SongsCompanion.insert(number: 18, title: 'Grateful for the Ransom'),
  SongsCompanion.insert(number: 19, title: "The Lord's Evening Meal"),
  SongsCompanion.insert(number: 20, title: 'You Gave Your Precious Son'),
  SongsCompanion.insert(number: 21, title: 'Keep On Seeking First the Kingdom'),
  SongsCompanion.insert(
    number: 22,
    title: 'The Kingdom Is in Place\u2014Let It Come!',
  ),
  SongsCompanion.insert(number: 23, title: 'Jehovah Begins His Rule'),
  SongsCompanion.insert(number: 24, title: "Come to Jehovah's Mountain"),
  SongsCompanion.insert(number: 25, title: 'A Special Possession'),
  SongsCompanion.insert(number: 26, title: 'You Did It for Me'),
  SongsCompanion.insert(number: 27, title: "The Revealing of God's Sons"),
  SongsCompanion.insert(number: 28, title: "Gaining Jehovah's Friendship"),
  SongsCompanion.insert(number: 29, title: 'Living Up to Our Name'),
  SongsCompanion.insert(number: 30, title: 'My Father, My God and Friend'),
  SongsCompanion.insert(number: 31, title: 'Oh, Walk With God!'),
  SongsCompanion.insert(number: 32, title: 'Take Sides With Jehovah!'),
  SongsCompanion.insert(number: 33, title: 'Throw Your Burden on Jehovah'),
  SongsCompanion.insert(number: 34, title: 'Walking in Integrity'),
  SongsCompanion.insert(
    number: 35,
    title: '"Make Sure of the More Important Things"',
  ),
  SongsCompanion.insert(number: 36, title: 'We Guard Our Hearts'),
  SongsCompanion.insert(number: 37, title: 'Serving Jehovah Whole-Souled'),
  SongsCompanion.insert(number: 38, title: 'He Will Make You Strong'),
  SongsCompanion.insert(number: 39, title: 'Make a Good Name With God'),
  SongsCompanion.insert(number: 40, title: 'To Whom Do We Belong?'),
  SongsCompanion.insert(number: 41, title: 'Please Hear My Prayer'),
  SongsCompanion.insert(number: 42, title: "The Prayer of God's Servant"),
  SongsCompanion.insert(number: 43, title: 'A Prayer of Thanks'),
  SongsCompanion.insert(number: 44, title: 'A Prayer of the Lowly One'),
  SongsCompanion.insert(number: 45, title: 'The Meditation of My Heart'),
  SongsCompanion.insert(number: 46, title: 'We Thank You, Jehovah'),
  SongsCompanion.insert(number: 47, title: 'Pray to Jehovah Each Day'),
  SongsCompanion.insert(number: 48, title: 'Daily Walking With Jehovah'),
  SongsCompanion.insert(number: 49, title: "Making Jehovah's Heart Glad"),
  SongsCompanion.insert(number: 50, title: 'My Prayer of Dedication'),
  SongsCompanion.insert(number: 51, title: 'To God We Are Dedicated!'),
  SongsCompanion.insert(number: 52, title: 'Christian Dedication'),
  SongsCompanion.insert(number: 53, title: 'Preparing to Preach'),
  SongsCompanion.insert(number: 54, title: '"This Is the Way"'),
  SongsCompanion.insert(number: 55, title: 'Fear Them Not!'),
  SongsCompanion.insert(number: 56, title: 'Make the Truth Your Own'),
  SongsCompanion.insert(number: 57, title: 'Preaching to All Sorts of People'),
  SongsCompanion.insert(number: 58, title: 'Searching for Friends of Peace'),
  SongsCompanion.insert(number: 59, title: 'Praise Jah With Me'),
  SongsCompanion.insert(number: 60, title: 'It Means Their Life'),
  SongsCompanion.insert(number: 61, title: 'Forward, You Witnesses!'),
  SongsCompanion.insert(number: 62, title: 'The New Song'),
  SongsCompanion.insert(number: 63, title: "We're Jehovah's Witnesses!"),
  SongsCompanion.insert(number: 64, title: 'Sharing Joyfully in the Harvest'),
  SongsCompanion.insert(number: 65, title: 'Move Ahead!'),
  SongsCompanion.insert(number: 66, title: 'Declare the Good News'),
  SongsCompanion.insert(number: 67, title: '"Preach the Word"'),
  SongsCompanion.insert(number: 68, title: 'Sowing Kingdom Seed'),
  SongsCompanion.insert(
    number: 69,
    title: 'Go Forward in Preaching the Kingdom!',
  ),
  SongsCompanion.insert(number: 70, title: 'Search Out Deserving Ones'),
  SongsCompanion.insert(number: 71, title: "We Are Jehovah's Army!"),
  SongsCompanion.insert(number: 72, title: 'Making Known the Kingdom Truth'),
  SongsCompanion.insert(number: 73, title: 'Grant Us Boldness'),
  SongsCompanion.insert(number: 74, title: 'Join in the Kingdom Song!'),
  SongsCompanion.insert(number: 75, title: '"Here I Am! Send Me!"'),
  SongsCompanion.insert(number: 76, title: 'How Does It Make You Feel?'),
  SongsCompanion.insert(number: 77, title: 'Light in a Darkened World'),
  SongsCompanion.insert(number: 78, title: '"Teaching the Word of God"'),
  SongsCompanion.insert(number: 79, title: 'Teach Them to Stand Firm'),
  SongsCompanion.insert(
    number: 80,
    title: '"Taste and See That Jehovah Is Good"',
  ),
  SongsCompanion.insert(number: 81, title: 'The Life of a Pioneer'),
  SongsCompanion.insert(number: 82, title: '"Let Your Light Shine"'),
  SongsCompanion.insert(number: 83, title: '"From House to House"'),
  SongsCompanion.insert(number: 84, title: 'Reaching Out'),
  SongsCompanion.insert(number: 85, title: 'Welcome One Another'),
  SongsCompanion.insert(number: 86, title: 'We Must Be Taught'),
  SongsCompanion.insert(number: 87, title: 'Come! Be Refreshed'),
  SongsCompanion.insert(number: 88, title: 'Make Me Know Your Ways'),
  SongsCompanion.insert(number: 89, title: 'Listen, Obey, and Be Blessed'),
  SongsCompanion.insert(number: 90, title: 'Encourage One Another'),
  SongsCompanion.insert(number: 91, title: 'Our Labor of Love'),
  SongsCompanion.insert(number: 92, title: 'A Place Bearing Your Name'),
  SongsCompanion.insert(number: 93, title: 'Bless Our Meeting Together'),
  SongsCompanion.insert(number: 94, title: "Grateful for God's Word"),
  SongsCompanion.insert(number: 95, title: 'The Light Gets Brighter'),
  SongsCompanion.insert(number: 96, title: "God's Own Book\u2014A Treasure"),
  SongsCompanion.insert(number: 97, title: "Life Depends on God's Word"),
  SongsCompanion.insert(
    number: 98,
    title: 'The Scriptures\u2014Inspired of God',
  ),
  SongsCompanion.insert(number: 99, title: 'Myriads of Brothers'),
  SongsCompanion.insert(number: 100, title: 'Receive Them With Hospitality'),
  SongsCompanion.insert(number: 101, title: 'Working Together in Unity'),
  SongsCompanion.insert(number: 102, title: '"Assist Those Who Are Weak"'),
  SongsCompanion.insert(number: 103, title: 'Shepherds\u2014Gifts in Men'),
  SongsCompanion.insert(number: 104, title: "God's Gift of Holy Spirit"),
  SongsCompanion.insert(number: 105, title: '"God Is Love"'),
  SongsCompanion.insert(number: 106, title: 'Cultivating the Quality of Love'),
  SongsCompanion.insert(number: 107, title: 'The Divine Pattern of Love'),
  SongsCompanion.insert(number: 108, title: "God's Loyal Love"),
  SongsCompanion.insert(number: 109, title: 'Love Intensely From the Heart'),
  SongsCompanion.insert(number: 110, title: '"The Joy of Jehovah"'),
  SongsCompanion.insert(number: 111, title: 'Our Reasons for Joy'),
  SongsCompanion.insert(number: 112, title: 'Jehovah, God of Peace'),
  SongsCompanion.insert(number: 113, title: 'Our Possession of Peace'),
  SongsCompanion.insert(number: 114, title: '"Exercise Patience"'),
  SongsCompanion.insert(number: 115, title: 'Gratitude for Divine Patience'),
  SongsCompanion.insert(number: 116, title: 'The Power of Kindness'),
  SongsCompanion.insert(number: 117, title: 'The Quality of Goodness'),
  SongsCompanion.insert(number: 118, title: '"Give Us More Faith"'),
  SongsCompanion.insert(number: 119, title: 'We Must Have Faith'),
  SongsCompanion.insert(number: 120, title: "Imitate Christ's Mildness"),
  SongsCompanion.insert(number: 121, title: 'We Need Self-Control'),
  SongsCompanion.insert(number: 122, title: 'Be Steadfast, Immovable!'),
  SongsCompanion.insert(
    number: 123,
    title: 'Loyally Submitting to Theocratic Order',
  ),
  SongsCompanion.insert(number: 124, title: 'Ever Loyal'),
  SongsCompanion.insert(number: 125, title: '"Happy Are the Merciful!"'),
  SongsCompanion.insert(
    number: 126,
    title: 'Stay Awake, Stand Firm, Grow Mighty',
  ),
  SongsCompanion.insert(number: 127, title: 'The Sort of Person I Should Be'),
  SongsCompanion.insert(number: 128, title: 'Enduring to the End'),
  SongsCompanion.insert(number: 129, title: 'We Will Keep Enduring'),
  SongsCompanion.insert(number: 130, title: 'Be Forgiving'),
  SongsCompanion.insert(number: 131, title: '"What God Has Yoked Together"'),
  SongsCompanion.insert(number: 132, title: 'Now We Are One'),
  SongsCompanion.insert(number: 133, title: 'Worship Jehovah During Youth'),
  SongsCompanion.insert(number: 134, title: 'Children Are a Trust From God'),
  SongsCompanion.insert(
    number: 135,
    title: 'Jehovah\'s Warm Appeal: "Be Wise, My Son"',
  ),
  SongsCompanion.insert(number: 136, title: '"A Perfect Wage" From Jehovah'),
  SongsCompanion.insert(
    number: 137,
    title: 'Faithful Women, Christian Sisters',
  ),
  SongsCompanion.insert(number: 138, title: 'Beauty in Gray-Headedness'),
  SongsCompanion.insert(number: 139, title: 'See Yourself When All Is New'),
  SongsCompanion.insert(number: 140, title: 'Life Without End\u2014At Last!'),
  SongsCompanion.insert(number: 141, title: 'The Miracle of Life'),
  SongsCompanion.insert(number: 142, title: 'Holding Fast to Our Hope'),
  SongsCompanion.insert(
    number: 143,
    title: 'Keep Working, Watching, and Waiting',
  ),
  SongsCompanion.insert(number: 144, title: 'Keep Your Eyes on the Prize!'),
  SongsCompanion.insert(number: 145, title: "God's Promise of Paradise"),
  SongsCompanion.insert(number: 146, title: '"Making All Things New"'),
  SongsCompanion.insert(number: 147, title: 'Life Everlasting Is Promised'),
  SongsCompanion.insert(number: 148, title: 'Jehovah Provides Escape'),
  SongsCompanion.insert(number: 149, title: 'A Victory Song'),
  SongsCompanion.insert(number: 150, title: 'Seek God for Your Deliverance'),
  SongsCompanion.insert(number: 151, title: 'He Will Call'),
  SongsCompanion.insert(
    number: 152,
    title: 'A Place That Will Bring You Praise',
  ),
  SongsCompanion.insert(number: 153, title: 'Give Me Courage'),
  SongsCompanion.insert(number: 154, title: 'Unfailing Love'),
  SongsCompanion.insert(number: 155, title: 'Our Joy Eternally'),
  SongsCompanion.insert(number: 156, title: 'With Eyes of Faith'),
  SongsCompanion.insert(number: 157, title: 'Peace at Last!'),
  SongsCompanion.insert(number: 158, title: '"It Will Not Be Late!"'),
  SongsCompanion.insert(number: 159, title: 'Give Jehovah Glory'),
  SongsCompanion.insert(number: 160, title: '"Good News"!'),
  SongsCompanion.insert(number: 161, title: 'To Do Your Will Is My Delight'),
  SongsCompanion.insert(number: 162, title: 'My Spiritual Need'),
];
