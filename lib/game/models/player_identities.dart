import '../../app/theme.dart';
import 'game_config.dart';
import 'player.dart';

const humanIdentity = PlayerIdentity(
  name: 'YOU',
  tag: 'P1',
  color: AppColors.p1,
  lightColor: AppColors.p1Light,
  isBot: false,
);

PlayerIdentity botIdentity(BotDifficulty difficulty) => PlayerIdentity(
  name: 'BOT',
  tag: 'P2',
  color: AppColors.p2,
  lightColor: AppColors.p2Light,
  isBot: true,
);
