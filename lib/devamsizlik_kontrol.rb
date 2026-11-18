# frozen_string_literal: true

# Dönem 10 oturum; %30 = 3 devamsızlık (tam 3 riskli), 4 ve üstü kaldı.
class DevamsizlikKontrol
  RISK_ESIGI = 3
  KALMA_ESIGI = 4
  KURALLAR = %i[riskli kaldi onur_adayi].freeze

  def initialize(ogrenci)
    @ogrenci = ogrenci
  end

  def riskli?
    @ogrenci.devamsizlik >= RISK_ESIGI
  end

  def kaldi?
    @ogrenci.devamsizlik >= KALMA_ESIGI
  end

  def onur_adayi?
    @ogrenci.aktif? && @ogrenci.devamsizlik.zero?
  end

  def kurallar
    KURALLAR.select { |k| public_send(:"#{k}?") }
  end
end
