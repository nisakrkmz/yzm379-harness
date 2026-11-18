# RATCHET_LOG — Hata → Kalıcı Kural

Her satır A koşusunda **gözlenen** bir hatadır. Kanıtlar `kanit/a_kosusu/` altındadır.
Ajan: Claude Code 2.1.327, model `sonnet` (claude-sonnet-5-5), Ruby 3.4.12, Windows.
Prompt (1. tur): `Öğrenci devamsızlık kontrolü yap, devamsızlık sınırı %30'dur.`

Katmanlar: **Rehber** = `AGENTS.md`, **Sensör** = `test/ogrenci_test.rb`, **Kanca** = `bin/kontrol` (+ `.claude/settings.json`).

## A koşusunda gözlenen hatalar

| # | Karşılaşılan hata | Kanıt | Kalıcı kural / test | Katman | B'de |
|---|---|---|---|---|---|
| A1-1 | Sınır `>` ile yazıldı; tam %30 "Geçti" sayıldı | `tur1_lib/devamsizlik_kontrol.rb.txt`: `ogrenci.devamsizlik_orani > limit` ve "tam %30 sınırda kabul edilir" yorumu; `a_tur1.jsonl` sonucunda "Mehmet %30.0 Geçti" | AGENTS §Alan 2 · `test_tam_3_devamsizlik_riskli_sayilir`, `test_3_ustu_riskli` | Rehber + Sensör + Kanca | ✅ `>= RISK_ESIGI`, test yeşil |
| A1-2 | Riskli/kaldı ayrımı yok; %30 doğrudan "kaldı" eşiği | `tur1_lib`: tek `kaldi:` anahtarı | AGENTS §Alan 3 · `test_tam_3_devamsizlik_kalmaz`, `test_tam_4_devamsizlik_kaldi`, `test_4_devamsizlik_hem_riskli_hem_kaldi` | Rehber + Sensör | ✅ ayrı `riskli?` / `kaldi?` |
| A1-3 | 10 oturum bilinmiyor; saat bazlı Float oran | `tur1_lib/ogrenci.rb.txt`: `devamsiz_ders * 100.0 / toplam_ders` | AGENTS §Alan 1 · `test_devamsizlik_sinirlari_0_ve_10_kabul_edilir`, `test_devamsizlik_araligi_disi_reddedilir` (2.5, "3", nil, -1, 11) | Rehber + Sensör | ✅ `between?(0, 10)`, Float yok |
| A1-4 | `durum` alanı ve `aktif?`/`mezun?` sorguları yok | `tur1_lib/ogrenci.rb.txt`: yalnızca `ad, toplam_ders, devamsiz_ders` | AGENTS §Alan 6, §Metaprogramlama · `test_durum_sorgulari_dogru_cevap_verir`, `test_durum_sorgulari_acik_ve_aranabilir`, `test_gecersiz_durum_reddedilir` | Rehber + Sensör | ✅ `define_method` ile |
| A1-5 | Test yazılmadı; `lib/` içine uydurma veriyle `puts` demo kondu | `tur1_lib/devamsizlik_kontrol.rb.txt`: `if $PROGRAM_NAME == __FILE__` bloğu | AGENTS §Görev, §Doğrulama · `bin/kontrol` testleri zorunlu çalıştırır | Rehber + Kanca | ✅ demo yok; ajan `ruby bin/kontrol`'ü kendisi de çalıştırdı |
| A1-6 | Görevi kod değil veri işleme sandı; veri istedi | `a_tur1.jsonl` sonuç metni: "gerçek öğrenci listesini paylaşın" | AGENTS §Görev | Rehber | ✅ veri istemeden kod yazdı |
| A2-1 | Test dosyası yanlış adla yazıldı (`test/devamsizlik_test.rb`) | `tur2_test/devamsizlik_test.rb.txt` | Test dosyası harness'ta hazır; AGENTS §Doğrulama "testleri değiştirme"; `bin/kontrol` sabit yolu çalıştırır | Sensör + Kanca | ✅ testlere dokunmadı (`git diff` boş) |
| A2-2 | Bilinmeyen metot testi yok | `tur2_test/devamsizlik_test.rb.txt` | `test_bilinmeyen_metot_no_method_error_firlatir` | Sensör | ✅ test yeşil |
| A2-3 | `durum` için istenmemiş varsayılan (`durum = :aktif`) | `tur2_lib/ogrenci.rb.txt`: `def initialize(ad, devamsizlik, durum = :aktif)` | AGENTS §Alan 6 · `test_alanlar_zorunlu_varsayilan_yok` | Rehber + Sensör | ✅ üç keyword zorunlu |
| A2-4 | Arayüz belirsiz: sıralı argüman + sınıf metotları (`DevamsizlikKontrol.riskli?(o)`) | `tur2_lib/*.rb.txt` | AGENTS §Arayüz · testlerin tamamı bu arayüzü kullanır | Rehber + Sensör | ✅ birebir arayüz |

> A2-4 bir şartname ihlali değil, **arayüz belirsizliği**dir: şartname arayüzü tanımlamıyor. Harness bunu tek bir arayüze sabitler.

## Önleyici kurallar (bu A koşusunda gözlenmedi)

| # | Risk | Neden yine de kilitlendi | Kalıcı kural / test | Katman | B'de |
|---|---|---|---|---|---|
| Ö-1 | `method_missing` / monkey patch / `refine` | Şartnamede 0 puan sebebi; A'da ajan `define_method`'u kendisi seçti, ama bu garanti değil | AGENTS §Metaprogramlama · `test_method_missing_tanimlanmamis`, `test_standart_siniflara_monkey_patch_yok` · `bin/kontrol` YASAK taraması | Rehber + Sensör + Kanca | ✅ yok (kanca YASAK taraması temiz) |
| Ö-2 | Yanlış Ruby sürümü | Pilot koşu yanlışlıkla Ruby 3.3 ile yapıldı | `.ruby-version` · `bin/kontrol` SÜRÜM kontrolü | Kanca | ✅ `[SÜRÜM]` hatası yok |

## B koşusunda gözlenen ve sonradan kilitlenen (yeni mandal)

B koşusu (`kanit/b_kosusu/b_tur1.jsonl`, `kanit/kanca.log`) şartnameyi tek turda karşıladı, ama iki verimsizlik gösterdi. Bunlar B'den **sonra** `AGENTS.md`'ye eklendi (ayrı commit); henüz bir koşuda sınanmadı.

| # | Gözlenen | Kanıt | Kalıcı kural | Katman |
|---|---|---|---|---|
| B-1 | Ajan dosyaları önce Bash heredoc ile, `bin/kontrol`'ü PowerShell ile çalıştırmayı denedi; ikisi de izinsizdi → 2 boşa tur | `b_tur1.jsonl` → `permission_denials` (Bash heredoc, PowerShell) | AGENTS §Araçlar: Write/Edit kullan, komut olarak yalnızca `ruby` | Rehber |
| B-2 | Kanca ilk dosya yazılınca kırmızı döndü; ikinci dosya henüz yoktu (gerçek hata değil, ara durum) | `kanca.log` 21:50:51 BAŞARISIZ → 21:50:54 TAMAM | AGENTS §Araçlar: iki dosyayı arka arkaya yaz | Rehber |

## Deney süreci hataları (ajan hatası değil)

| # | Hata | Düzeltme |
|---|---|---|
| S-1 | Pilot koşu Ruby 3.3 açıkken yapıldı | Ruby 3.4.12 kuruldu, A baştan koşuldu (`pilot_ruby33.jsonl` saklandı) |
| S-2 | Pilot koşuda log dosyası klasörün içindeydi; ajan kendi logunu okudu | Loglar çalışma klasörünün dışına (`..\kanit-a\`) yazıldı |
| S-3 | PowerShell `echo >` dosyaları UTF-16 yazdı, `\` satır devamı çalışmadı | `Set-Content -Encoding ascii` ve tek satırlık komutlar kullanıldı |
| S-4 | A ile B arasında ~80 dk geçti; Claude Code'un 1 saatlik prompt önbelleği B'de soğuktu, A 1. turda ise pilottan sıcak kalmıştı | README "Token analizi" bölümünde karıştırıcı etken olarak raporlandı |
