# YZM379 · Öğrenci Devamsızlık Kural Motoru — Model + Harness

> **Ajan = Model + Harness.** Aynı model, aynı prompt; tek değişken harness'tır.

## Çalıştırma

```bash
ruby -v                                   # 3.4.x
ruby -Ilib -Itest test/ogrenci_test.rb    # Minitest: 20 test (bkz. "Testler")
ruby bin/kontrol                          # tüm kapı: sürüm + sözdizimi + yasaklar + testler
```

```ruby
o = Ogrenci.new(ad: "Ayşe", durum: :aktif, devamsizlik: 3)
o.aktif?                                  # => true
DevamsizlikKontrol.new(o).kurallar        # => [:riskli]
```

| Kural | Koşul | Sınır vakası |
|---|---|---|
| `riskli?` | `devamsizlik >= 3` (10 oturumda %30) | **tam 3 → riskli** |
| `kaldi?` | `devamsizlik >= 4` | 3 → kalmaz, 4 → kalır (ve riskli) |
| `onur_adayi?` (özgün kural) | `aktif?` ve `devamsizlik == 0` | 0 + mezun → değil, 1 + aktif → değil |

## Testler (Minitest) — durum: 🟢 YEŞİL

Testlerin tamamı tek dosyada: **[`test/ogrenci_test.rb`](test/ogrenci_test.rb)** — **20 test, hepsi yeşil.**

```bash
ruby -Ilib -Itest test/ogrenci_test.rb
```

Beklenen son satır: `20 runs, … assertions, 0 failures, 0 errors, 0 skips`
(Assertion sayısı Ruby sürümüne göre değişir; monkey patch testi standart sınıfların tüm metotlarını tarar.)
Ruby 3.4.12 üzerindeki gerçek çıktı: **[`kanit/test_ciktisi.txt`](kanit/test_ciktisi.txt)**.

| Test | Neyi kilitler | RATCHET_LOG |
|---|---|---|
| `test_tam_3_devamsizlik_riskli_sayilir` | **SINIR VAKA: tam 3 devamsızlık riskli** (`>= 3`) | A1-1 |
| `test_2_devamsizlik_riskli_degil` | 2 → riskli değil | A1-1 |
| `test_3_ustu_riskli` | 0..2 riskli değil, 3..10 riskli (tüm aralık) | A1-1 |
| `test_tam_3_devamsizlik_kalmaz` | 3 → kalmaz | A1-2 |
| `test_tam_4_devamsizlik_kaldi` | 4 → kaldı | A1-2 |
| `test_4_devamsizlik_hem_riskli_hem_kaldi` | 4 → hem riskli hem kaldı | A1-2 |
| `test_devamsizlik_sinirlari_0_ve_10_kabul_edilir` | 0 ve 10 geçerli | A1-3 |
| `test_devamsizlik_araligi_disi_reddedilir` | −1, 11, 2.5, `"3"`, `nil` → `ArgumentError` | A1-3 |
| `test_alanlar_okunabilir` | `ad`, `durum`, `devamsizlik` okunur | A1-4 |
| `test_durum_sorgulari_dogru_cevap_verir` | `aktif?`, `donduruldu?`, `mezun?` doğru | A1-4 |
| `test_durum_sorgulari_acik_ve_aranabilir` | Sorgular `define_method` ile gerçekten tanımlı (`instance_methods`, `respond_to?`) | A1-4 |
| `test_gecersiz_durum_reddedilir` | `:silindi`, `"aktif"` → `ArgumentError` | A1-4 |
| `test_alanlar_zorunlu_varsayilan_yok` | Üç keyword zorunlu, varsayılan yok | A2-3 |
| `test_bilinmeyen_metot_no_method_error_firlatir` | **Bilinmeyen metot** → `NoMethodError`, `respond_to?` false | A2-2 |
| `test_method_missing_tanimlanmamis` | `method_missing` tanımlanmamış (sahibi `BasicObject`) | Ö-1 |
| `test_standart_siniflara_monkey_patch_yok` | `lib/` hiçbir standart sınıfa metot eklemiyor | Ö-1 |
| `test_aktif_ve_sifir_devamsizlik_onur_adayi` | Özgün kural: aktif + 0 → onur adayı | — |
| `test_tek_devamsizlik_onur_adayligini_bozar` | aktif + 1 → değil | — |
| `test_aktif_olmayan_onur_adayi_olamaz` | mezun/dondurulmuş + 0 → değil | — |
| `test_kurallar_listesi` | `kurallar` → `[]`, `[:riskli]`, `[:riskli, :kaldi]`, `[:onur_adayi]` | — |

Testler ayrıca `ruby bin/kontrol` tarafından ve ajan her dosya kaydettiğinde kanca tarafından otomatik çalıştırılır (bkz. aşağıda).

## Harness

| Katman | Dosya | Görevi |
|---|---|---|
| Rehber | `AGENTS.md` (`CLAUDE.md` → sembolik bağ) | Eğitim verisinde olmayan, şüpheye açık kurallar: 10 oturum, tam 3 riskli, arayüz, metaprogramlama yasakları |
| Sensör | `test/ogrenci_test.rb` | Sınır vakaları (2/3/4, 0/10, −1/11), bilinmeyen metot, `method_missing` ve monkey patch denetimi |
| Kanca | `bin/kontrol` + `.claude/settings.json` | Ajan her `Edit`/`Write` yaptığında otomatik çalışır; hata varsa `exit 2` ile raporu ajanın önüne atar |
| Ölçüm | `bin/olcum` | `stream-json` loglarından tur, token, maliyet, izin reddi sayılarını çıkarır |

### `bin/kontrol` kancası

`.claude/settings.json` içinde `PostToolUse` hook'u olarak tanımlıdır:

```json
{ "hooks": { "PostToolUse": [ { "matcher": "Edit|Write|MultiEdit",
  "hooks": [ { "type": "command", "command": "ruby bin/kontrol" } ] } ] } }
```

Sırasıyla şunları kontrol eder:
1. `.ruby-version` ve çalışan Ruby 3.4 mü?
2. `ruby -c` ile sözdizimi
3. `lib/` içinde yasak kalıplar: `method_missing`, `respond_to_missing?`, `refine`, standart sınıfın yeniden açılması
4. Minitest

Hepsi geçerse `exit 0`, biri bile kalırsa raporu STDERR'e yazıp `exit 2`. Claude Code, `exit 2` çıktısını ajana geri besler; ajan düzeltmeden bitiremez. Her çalışma `kanit/kanca.log`'a `[kanca]` (hook) ya da `[elle]` etiketiyle yazılır.

Kancanın kendisi de sınandı (referans kod üzerinde bilerek hata eklenerek):

| Bilerek eklenen hata | Yakalayan |
|---|---|
| `>= 3` → `> 3` | Sensör (3 test kırmızı) |
| `def method_missing` | Kanca YASAK + Sensör |
| `class Integer; def riskli? …` | Kanca YASAK + Sensör |

## Deney protokolü

- **Ajan:** Claude Code 2.1.327, headless: `claude -p … --model sonnet --output-format stream-json --verbose --permission-mode acceptEdits --allowedTools "Bash(ruby:*)"`
- **Ortam:** Windows, PowerShell, Ruby 3.4.12
- **Başlangıç durumu (A ve B aynı):** `.ruby-version` + boş `class Ogrenci; end` ve `class DevamsizlikKontrol; end`
- **Prompt (A ve B aynı):** `Öğrenci devamsızlık kontrolü yap, devamsızlık sınırı %30'dur.`
- **Fark:** B'de `AGENTS.md`/`CLAUDE.md`, `test/ogrenci_test.rb`, `bin/kontrol` ve hook mevcut.
- **Zaman çizelgesi:** pilot ~20:08 · A 1. tur ~20:27 · A 2. tur ~20:30 · B 21:50.
- **A'da düzeltme kuralı:** her insan turunda yalnızca gözlenen hatalar söylendi, çözüm yöntemi (ör. `define_method`) söylenmedi.
- **Loglar:** çalışma klasörünün **dışına** yazıldı (pilotta ajan kendi logunu okudu, bkz. `RATCHET_LOG.md` S-2).

## A/B Koşusu ve Ölçüm Raporu

Sayılar `ruby bin/olcum <log>` çıktısıdır; ham loglar `kanit/` altında. Kanca kayıtları `kanit/kanca.log`.

| Metrik | A (rehbersiz) | B (harness) | Fark |
|---|---|---|---|
| İnsan turu (prompt sayısı) | 2 | **1** | −1 (−%50) |
| Ajan turu (`num_turns`) | 12 (7 + 5) | **7** | −5 (−%42) |
| Süre (sn) | 52,6 | **33,0** | −%37 |
| Input token (önbelleksiz) | 12 | 11 | −1 |
| Cache yazma token | 13.982 | 34.182 | +20.200 (+%144) |
| Cache okuma token | 173.592 | 230.612 | +57.020 (+%33) |
| Output token | 5.554 | **2.818** | −2.736 (−%49) |
| **Toplam işlenen token** | **193.140** | 267.623 | **+74.483 (+%39)** |
| **Maliyet (USD)** | **0,1289** | 0,1880 | **+0,0591 (+%46)** |
| İzin reddi (boşa giden araç çağrısı) | 0 | 2 | +2 |
| İlk çıktıda şartname ihlali | 6 (A1-1…A1-6) | **0** | |
| Kancanın ajanı durdurması | — (kanca yok) | 1 (ara durum, bkz. B-2) | |
| Son durum: `ruby bin/kontrol` | — | **tamam (20/20 test)** | |

**Şartname kontrol listesi (tur sonunda):**

| Madde | A · 1. tur | A · 2. tur | B · 1. tur |
|---|---|---|---|
| Tam 3 = riskli (`>= 3`) | ❌ `>` | ✅ | ✅ |
| Riskli ve kaldı ayrı | ❌ | ✅ | ✅ |
| 0..10 tam sayı | ❌ saat/Float | ✅ | ✅ |
| `durum` + `define_method` sorguları | ❌ yok | ✅ | ✅ |
| `method_missing` / monkey patch yok | ✅ | ✅ | ✅ |
| Özgün kural | ❌ | ✅ | ✅ |
| Minitest (doğru dosya + bilinmeyen metot) | ❌ yok | ⚠️ yanlış dosya, bilinmeyen metot yok | ✅ |
| **Toplam** | **1/7** | **5/7** (+ istenmemiş `durum = :aktif` varsayılanı) | **7/7** |

### Kanca gerçekten çalıştı mı? (kanıt)

`kanit/kanca.log` — `[kanca]` = Claude Code hook'u tetikledi, `[elle]` = hook dışı çalıştırma:

```
2026-11-18 21:50:51 [kanca] BAŞARISIZ: [TEST] Minitest kırmızı (test/ogrenci_test.rb):
2026-11-18 21:50:54 [kanca] TAMAM
2026-11-18 21:51:02 [elle] TAMAM      ← ajanın kendisi (Bash: `ruby bin/kontrol`, AGENTS.md §Doğrulama)
2026-11-18 21:51:58 [elle] TAMAM      ← benim kontrolüm
```

Ajan `lib/ogrenci.rb`'yi yazınca kanca kırmızı döndü (`DevamsizlikKontrol` henüz yoktu), ikinci dosya yazılınca yeşile döndü. Ajan bitirmeden önce `bin/kontrol`'ü bir kez de kendisi çalıştırdı: Bash çağrıları arasında `"command":"ruby bin/kontrol"` var. `git diff --stat -- test AGENTS.md bin .claude` boş: **ajan testlere ve kurallara dokunmadı.**

### Token analizi: rehber kazandırdı mı?

**Bu ölçümde token ve para açısından hayır.** B, A'dan %39 daha fazla token işledi ve %46 daha pahalıya geldi. Kazanç başka eksenlerde:

1. **İnsan emeği:** 2 tur → 1 tur. A'nın 2. turunda şartnameyi ben elle yazdım; o emek token tablosunda görünmüyor. B'de aynı bilgi `AGENTS.md` + testlerden geldi.
2. **Doğruluk:** A iki turdan sonra 5/7'de kaldı (yanlış test dosyası, bilinmeyen metot testi yok, istenmemiş varsayılan). Bunları kapatmak en az bir tur daha isterdi. B 7/7, 20/20 test.
3. **Ajan turu ve süre:** 12 → 7 tur, 52,6 → 33,0 sn. Output token yarıya indi (−%49): B gevezelik, demo ve kendi test dosyası yazmadı, testler hazırdı.

**Neden daha pahalı?**

- **Daha büyük bağlam.** B her turda `AGENTS.md`, 20 testlik dosya ve `bin/kontrol` çıktısını taşıdı. Cache okuma +%33.
- **2 boşa tur.** Ajan izinsiz yolları (Bash heredoc, PowerShell) denedi. `AGENTS.md` §Araçlar ile kilitlendi (B-1).
- **Karıştırıcı etken: önbellek zamanlaması (S-4).** Claude Code sistem promptunu 1 saatlik önbelleğe yazar. A 1. tur, pilot koşudan ~20 dk sonra koştu; önbellek sıcaktı ve yalnızca 9.537 token yazıldı. B, A'dan ~80 dk sonra koştu; önbellek soğumuştu. Dayanak: aynı klasörde soğuk başlayan **pilot koşu 33.784 token** cache yazdı, **B ise 34.182**. Neredeyse aynı. Yani B'nin +20.200 cache yazma farkının büyük kısmı harness'tan değil zamanlamadan geliyor olabilir. Bunu kesinleştirmek için A ve B'nin aynı önbellek koşullarında, arka arkaya tekrarlanması gerekir (bkz. Yapamadıklarım).

**Sonuç:** Harness bu küçük görevde parayı değil **insan turunu ve hatayı** azalttı. Rehberin girdi maliyeti sabit; düzeltme turu ise hata sayısıyla büyür. Görev büyüdükçe ve A'nın düzeltme turu arttıkça denge B lehine döner. Bu koşudaki veri bunu **kanıtlamıyor**, yalnızca yönünü gösteriyor.

### Gözlemler

- **A'nın asıl hatası alan bilgisi eksikliğiydi**, sözdizimi değil. "%30"u saat bazlı oran ve `>` (aşarsa) olarak yorumladı; riskli/kaldı ayrımını ve 10 oturumu bilmiyordu.
- `method_missing`/monkey patch riski A'da **gerçekleşmedi**; ajan `define_method`'u kendisi seçti. Kural yine de önleyici olarak kilitlendi (Ö-1) ve B'de de temiz kaldı.
- Ratchet B'de de sürdü: B'nin verimsizlikleri (B-1, B-2) yeni `AGENTS.md` maddelerine dönüştü.

## Yapamadıklarım

- **Tek örnek (n = 1).** A ve B birer kez koşuldu; model deterministik değil (pilot koşu ile A 1. tur aynı promptla farklı davrandı: pilot hiç kod yazmadı). Ortalama ve sapma veremiyorum.
- **Önbellek koşullarını eşitleyemedim (S-4).** A sıcak, B soğuk önbellekle koştu; maliyet karşılaştırması bu yüzden B aleyhine çarpık olabilir.
- **A'nın 2. tur promptu şartnameyi içeriyordu.** Bu A'yı olduğundan iyi gösterir; hataları tek tek söyleyen daha "saf" bir A daha fazla tura çıkardı.
- **B sonrası eklenen B-1/B-2 kurallarını yeni bir koşuyla sınamadım.**
- **Pilot koşu** yanlış Ruby sürümüyle ve log klasör içindeyken yapıldı; geçersiz sayıldı ama `kanit/a_kosusu/pilot_ruby33.jsonl` olarak saklandı.
- **Kanca sayımı.** `bin/olcum` hook'un ajanı kaç kez durdurduğunu güvenilir sayamıyor (aynı mesaj logda birden çok yerde geçiyor). Bu yüzden kaynak olarak `kanit/kanca.log` kullanıldı.
