# YZM379 · Öğrenci Devamsızlık Kural Motoru — Model + Harness

> **Ajan = Model + Harness.** Aynı model, aynı prompt; tek değişken harness'tır.

## Çalıştırma

```bash
ruby -v                                   # 3.4.x
ruby -Ilib -Itest test/ogrenci_test.rb    # Minitest
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

## Harness

| Katman | Dosya | Görevi |
|---|---|---|
| Rehber | `AGENTS.md` (`CLAUDE.md` → sembolik bağ) | Eğitim verisinde olmayan, şüpheye açık kurallar: 10 oturum, tam 3 riskli, arayüz, metaprogramlama yasakları |
| Sensör | `test/ogrenci_test.rb` | Sınır vakaları (2/3/4, 0/10, −1/11), bilinmeyen metot, `method_missing` ve monkey patch denetimi |
| Kanca | `bin/kontrol` + `.claude/settings.json` | Ajan her `Edit`/`Write` yaptığında otomatik çalışır; hata varsa `exit 2` ile raporu ajanın önüne atar |
| Ölçüm | `bin/olcum` | `stream-json` loglarından tur, token, maliyet, kanca engeli sayılarını çıkarır |

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

Hepsi geçerse `exit 0`, biri bile kalırsa raporu STDERR'e yazıp `exit 2`. Claude Code, `exit 2` çıktısını ajana geri besler; ajan düzeltmeden bitiremez.

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
- **A'da düzeltme kuralı:** her insan turunda yalnızca gözlenen hatalar söylendi, çözüm yöntemi (ör. `define_method`) söylenmedi.
- **Loglar:** çalışma klasörünün **dışına** yazıldı (pilotta ajan kendi logunu okudu, bkz. `RATCHET_LOG.md` S-2).

## A/B Koşusu ve Ölçüm Raporu

Sayılar `ruby bin/olcum <log>` çıktısıdır. Ham loglar `kanit/` altında.

| Metrik | A (rehbersiz) | B (harness) | Fark |
|---|---|---|---|
| İnsan turu (prompt sayısı) | **2** | _B sonrası_ | |
| Ajan turu (`num_turns` toplamı) | **12** (7 + 5) | | |
| Input token (önbelleksiz) | 12 | | |
| Cache yazma token | 13.982 | | |
| Cache okuma token | 173.592 | | |
| Output token | 5.554 | | |
| **Toplam işlenen token** | **193.140** | | |
| **Maliyet (USD)** | **0.1289** | | |
| Süre (sn) | 52,6 | | |
| İlk çıktıda şartname ihlali | 6 (A1-1…A1-6) | | |
| Kancanın ajanı durdurma sayısı | — (kanca yok) | | |
| Son durum: `ruby bin/kontrol` | — | | |

**Şartname kontrol listesi (tur sonunda):**

| Madde | A · 1. tur | A · 2. tur | B · 1. tur |
|---|---|---|---|
| Tam 3 = riskli (`>= 3`) | ❌ `>` | ✅ | |
| Riskli ve kaldı ayrı | ❌ | ✅ | |
| 0..10 tam sayı | ❌ saat/Float | ✅ | |
| `durum` + `define_method` sorguları | ❌ yok | ✅ | |
| `method_missing` / monkey patch yok | ✅ | ✅ | |
| Özgün kural | ❌ | ✅ | |
| Minitest (doğru dosya + bilinmeyen metot) | ❌ yok | ⚠️ yanlış dosya, bilinmeyen metot yok | |

### Gözlemler

- **A'nın asıl hatası alan bilgisi eksikliğiydi**, sözdizimi değil: "%30" ifadesini saat bazlı oran ve `>` (aşarsa) olarak yorumladı; riskli/kaldı ayrımını ve 10 oturumu bilmiyordu.
- A'nın 2. turunda bu bilgiyi sohbet içinde verdim, yani **harness'ın işini elle yaptım**. B, aynı bilginin `AGENTS.md` + testlerle verildiğinde insan müdahalesi olmadan tek turda sonuca ulaşıp ulaşmadığını ölçer.
- `method_missing`/monkey patch riski bu A koşusunda **gerçekleşmedi**; ajan `define_method`'u kendisi seçti. Kural yine de önleyici olarak kilitlendi (`RATCHET_LOG.md` Ö-1).
- _B sonrası: token analizi — rehber girdi tokenını ne kadar artırdı, toplamda kazandırdı mı?_

## Yapamadıklarım

- **Tek örnek (n = 1).** Her koşu bir kez yapıldı; model deterministik değil (pilot koşu ile A 1. tur aynı promptla farklı davrandı: pilot hiç kod yazmadı). Ortalama ve sapma veremiyorum.
- **A'nın 2. tur promptu şartnameyi içeriyordu.** Bu, A'yı olduğundan iyi gösterir; daha "saf" bir A, hataları tek tek söyleyerek daha fazla tura çıkardı.
- **Token karşılaştırmasında önbellek etkisi:** Claude Code'un sistem promptu önbelleğe alındığı için toplam token ağırlıklı olarak cache okumasıdır; maliyet (USD) bu yüzden token sayısından daha adil bir ölçüdür.
- **Pilot koşu** yanlış Ruby sürümüyle ve log klasör içindeyken yapıldı; geçersiz sayıldı ama `kanit/a_kosusu/pilot_ruby33.jsonl` olarak saklandı.
