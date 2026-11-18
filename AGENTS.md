# AGENTS.md — Anayasa

Bu maddeler pazarlık konusu değildir. Şüphede kalırsan madde kazanır, varsayım değil.
Köşeli parantezdeki kod, kuralın doğduğu hatanın `RATCHET_LOG.md` satırıdır.

## Görev
- Görev **kod yazmaktır**: `lib/ogrenci.rb` ve `lib/devamsizlik_kontrol.rb`. Veri dosyası yoktur; veri isteme, örnek veri uydurma. [A1-6]
- `lib/` içine `puts`, demo, `if $PROGRAM_NAME == __FILE__` bloğu yazma. [A1-5]

## Ortam
- Ruby **3.4** (`.ruby-version`). Yalnızca stdlib + Minitest. Gem, Gemfile, Rails, ActiveSupport yok.

## Alan kuralları
1. Dönem **10 oturumdur**. `devamsizlik` **0..10 arası Integer**. Başka her değer → `ArgumentError`. Yüzde, oran, saat, Float hesabı yapma. [A1-3]
2. %30 = **3 devamsızlık**. `riskli?` ⇔ `devamsizlik >= 3`. **TAM 3 RİSKLİDİR.** `> 3` yazmak yasaktır. [A1-1]
3. `kaldi?` ⇔ `devamsizlik >= 4`. 4 ve üstü **hem riskli hem kaldı** sayılır. [A1-2]
4. `onur_adayi?` ⇔ `aktif?` **ve** `devamsizlik == 0`. Mezun ve dondurulmuş öğrenci onur adayı olamaz.
5. `riskli?` ve `kaldi?` durumdan bağımsızdır; yalnızca devamsızlığa bakar.
6. `durum` yalnızca `:aktif`, `:donduruldu`, `:mezun` olabilir. **Zorunludur, varsayılan değeri yoktur.** Başka değer → `ArgumentError`. [A1-4, A2-3]

## Arayüz (testler tam olarak bunu bekler) [A2-4]
```ruby
o = Ogrenci.new(ad: "Ayşe", durum: :aktif, devamsizlik: 3)  # üç keyword de zorunlu
o.ad; o.durum; o.devamsizlik
o.aktif?; o.donduruldu?; o.mezun?

k = DevamsizlikKontrol.new(o)
k.riskli?; k.kaldi?; k.onur_adayi?
k.kurallar  # => [:riskli, :kaldi, :onur_adayi] içinden geçerli olanlar, bu sırayla
```

## Metaprogramlama
- Durum sorguları `DURUMLAR.each { |d| define_method(:"#{d}?") { ... } }` ile üretilir: açık, `respond_to?` ve `instance_methods` ile aranabilir. [A1-4]
- `method_missing`, `respond_to_missing?`, `refine` **YASAK**. [Ö-1]
- Standart sınıflar (`Integer`, `String`, `Object`, …) yeniden açılamaz, dışarıdan metot eklenemez: **monkey patch YASAK**. [Ö-1]
- Bilinmeyen metot `NoMethodError` fırlatır. [A2-2]

## Doğrulama
- Testler `test/ogrenci_test.rb` içindedir. **Testleri değiştirme, silme, `skip` etme.** Kod testlere uyar. [A2-1]
- Her değişiklikten sonra `ruby bin/kontrol` çalışır (kanca bunu otomatik yapar). Çıkış kodu 2 ise **bitirme, düzelt.** [A1-5]
- İş, `ruby bin/kontrol` "tamam" demeden bitmiş sayılmaz.
