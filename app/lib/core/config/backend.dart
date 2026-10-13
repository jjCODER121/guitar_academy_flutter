/// Адрес проекта Supabase и publishable-ключ. Оба значения не секретные:
/// данные защищают правила RLS в базе и проверки в серверных функциях.
/// Секретные ключи (service_role, R2) в приложение не попадают никогда.
abstract final class Backend {
  static const supabaseUrl = 'https://aqihlmikvzdfiutmuwdd.supabase.co';
  static const supabaseKey = 'sb_publishable_R-Ah1k4MgRdGc7n-0gb6mA_x-xDWJIC';
}
