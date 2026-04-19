  <img src="assets/offveil-logo.svg" alt="OffVeil" width="400" />
</p>

<h3 align="center">
  macOS için Native ağ gizliliği motoru - VPN yok, harici sunucu yok, hız kaybı yok.
</h3>

<p align="center">
  <a href="https://github.com/berkaykyb/offveil-macOS/releases"><img src="https://img.shields.io/github/v/release/berkaykyb/offveil-macOS?style=flat-square&color=00c896&label=sürüm" alt="Release" /></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/lisans-Tüm%20Hakları%20Saklıdır-red?style=flat-square" alt="License" /></a>
  <a href="https://github.com/berkaykyb/offveil-macOS/stargazers"><img src="https://img.shields.io/github/stars/berkaykyb/offveil-macOS?style=flat-square&color=ffcc00" alt="Stars" /></a>
  <a href="https://github.com/berkaykyb/offveil-macOS/releases"><img src="https://img.shields.io/github/downloads/berkaykyb/offveil-macOS/total?style=flat-square&color=00c896&label=indirme" alt="Downloads" /></a>
</p>

<p align="center">
  <a href="README.md">English</a>
</p>

---

## offveil Nedir?

**offveil** (off the veil - *perdenin ötesi*), İnternet Servis Sağlayıcılarının (İSS) ağ trafiğinizi alan adı (SNI) bilgisine göre analiz etmesine ve kısıtlamasına olanak tanıyan **Derin Paket İncelemesi (DPI)** tekniğine karşı bağlantınızı koruyan hafif bir sistem menüsü uygulamasıdır.

Geleneksel VPN'lerin aksine, OffVeil **trafiğinizi asla üçüncü taraf sunucular üzerinden yönlendirmez**. Tamamen yerel makinenizde çalışır; standart TCP/TLS parçalama (fragmentation) tekniklerini uygulayarak İSS'nin trafiğinizdeki SNI alanını okumasını engeller. Bağlantınız doğrudan kalır, hızınızdan ödün verilmez ve tarama verileriniz cihazınızda kalır.

Her şey cihazınızda gerçekleşir; bu da maksimum gizlilik ve sıfır gecikme anlamına gelir.

---

## Özellikler

- **Tek Tıkla Koruma:** Menü çubuğundan tek bir tuşla bağlantınızı anında güvence altına alır.
- **Akıllı Ağ Yönetimi:** Ağ durumundaki değişiklikleri otomatik olarak algılar (Wi-Fi ↔ Ethernet, uyku modu/uyanma) ve korumayı sorunsuzca yeniden başlatır.
- **Sağlam Kurtarma (Recovery):** Yerleşik bir denetleme süreci (watchdog), uygulama beklenmedik şekilde kapansa bile sistem proxy ayarlarınızın her zaman temiz ve sorunsuz bir şekilde eski haline getirilmesini sağlar.
- **Otomatik Yapılandırma:** Herhangi bir manuel terminal komutu gerektirmeden macOS sistem proxy ayarlarını (`networksetup`) dinamik olarak yönetir.
- **Enerji Verimli:** macOS için özel olarak üretilmiştir, minimum sistem kaynağı tüketimiyle arka planda sessizce çalışır.
- **Otomatik Güncelleme:** GitHub Releases üzerinden entegre güncelleme mekanizması.

---

## Ekran Görüntüleri

<table>
  <tr>
    <th align="center">Koruma Aktif</th>
    <th align="center">Koruma Pasif</th>
    <th align="center">Ayarlar - Genel</th>
    <th align="center">Ayarlar - Destek</th>
  </tr>
  <tr>
    <td align="center"><img src="assets/ss-active.png" width="240" /></td>
    <td align="center"><img src="assets/ss-inactive.png" width="240" /></td>
    <td align="center"><img src="assets/ss-settings.png" width="240" /></td>
    <td align="center"><img src="assets/ss-settings2.png" width="240" /></td>
  </tr>
</table>

---

## Teknik Mimari ve v2.0 Vizyonu

Şu anda (v1.x sürümünde), OffVeil macOS temel paket işleme motoru olarak [SpoofDPI](https://github.com/xvzc/SpoofDPI)'ı kullanmaktadır. Uygulama yerel bir proxy (`127.0.0.1:18080`) kurar ve TLS ClientHello parçalama işlemini gerçekleştirmek için tüm sistem HTTP/HTTPS trafiğini otomatik olarak bu proxy üzerinden yönlendirir.

### Neden henüz kernel seviyesinde müdahale etmiyoruz?

Apple platformlarında kernel düzeyinde bir ağ filtresi geliştirmek bir **Network Extension (Ağ Uzantısı)** uygulamayı gerektirir. Apple, bu yetkiyi kesin ve katı bir şekilde **Apple Developer Programı** arkasında tutmaktadır. Aktif ve onaylanmış bir geliştirici hesabı olmadan, Network Extension içeren kodlar sıradan kullanıcı makinelerinde imzalanamaz, test edilemez veya çalıştırılamaz.

### v2.0 Vizyonumuz

Bugün kullanıcılara çalışan, güvenilir ve ücretsiz bir uygulama sunabilmek için SpoofDPI'dan yararlanan yerel proxy (local-proxy) mimarisini benimsedik. **Ancak bu geçici bir basamaktır.**

Bir Apple Geliştirici hesabı (Apple Developer Account) temin ettiğimizde acil yol haritamız şunları içermektedir:

1. Çekirdek (kernel) düzeyinde paket manipülasyonu için native, **Swift tabanlı bir Network Extension** geliştirmek.
2. Yerel HTTP proxy mimarisini tamamen terk etmek.
3. Herhangi bir proxy gecikmesi olmaksızın sıfır ek yük (zero-overhead) hiper-verimli bir DPI bypass mimarisine ulaşmak.

O zamana kadar OffVeil, macOS DPI bypass ekosisteminde bulunan en sağlam ve yönetilebilir arayüzü sunmaya devam edecek.

---

## Karşılaştırma

macOS ağ gizliliği ekosistemi büyük ölçüde komut satırı (CLI) araçlarından oluşmaktadır. OffVeil, teknik etkinlik ile Apple platformlarında günlük kullanım kolaylığı arasındaki bu boşluğu doldurmayı hedefler.

| Özellik | **offveil (macOS)** | SpoofDPI (ham) | ByeDPI (ham) | Surge |
|---------|:-----------:|:--------:|:------:|:-----:|
| **Platform** | **macOS** | macOS | macOS | macOS |
| **Arayüz (UI)** | **Native GUI** | CLI (Terminal) | CLI (Terminal) | Native GUI |
| **Gizlilik Yöntemi** | **TLS Parçalama (Yerel Proxy)** | HTTP Proxy | SOCKS Proxy | Kural Tabanlı Proxy |
| **Sistem Proxy Yön.**| **Otomatik** | Manuel | Manuel | Otomatik |
| **Ağ Değişimi Tespiti**| **Otomatik** | Manuel | Manuel | Manuel |
| **Çökme Kurtarma** | **Otomatik** | Yok | Yok | Yok |
| **Oto-Güncelleme** | **Evet** | Hayır | Hayır | Evet |
| **Fiyat** | **Ücretsiz** | Ücretsiz | Ücretsiz | Ücretli (~$50+) |
| **Kullanım** | **Arka Plan Uygulaması**| Terminal Oturumu | Terminal Oturumu | Arka Plan Uygulaması |

---

## Kurulum

1. En guncel `offveil.dmg` dosyasini **[Releases (Surumler)](https://github.com/berkaykyb/offveil-macOS/releases)** sayfasindan indirin.
2. Indirilen `.dmg` dosyasini acin.
3. Icindeki **offveil** uygulamasini **Applications (Uygulamalar)** klasorune surukleyin.
4. **Ilk acilis icin:** offveil App Store uzerinden dagitilmadigi icin macOS tek seferlik bir onay gerektirir. **Terminal** uygulamasini acin ve asagidaki komutu yapistirin:
   ```bash
   xattr -cr /Applications/offveil.app
   ```
5. **offveil** uygulamasini Uygulamalar klasorunuzden acin.

Bu ilk kurulum adimlarindan sonra offveil tum sonraki acilislarda normal sekilde calisacaktir. Guncellemeler uygulama icinden otomatik olarak yapilir.

*macOS 13 Ventura veya daha guncel bir surum gerektirir. Apple Silicon (M serisi) ve Intel islemcili cihazlarda tamamen yerel (native) olarak calisir.*

---

## Teknolojik Altyapı

| Bileşen | Teknoloji |
|-------|-----------|
| **Kullanıcı Arayüzü (UI)** | SwiftUI |
| **Durum ve Yaşam Döngüsü** | Python 3 (PyInstaller ile binary olarak derlenmiştir) |
| **Proxy Motoru** | [SpoofDPI](https://github.com/xvzc/SpoofDPI) (Go binary) |
| **Ağ Yönlendirmesi** | `Network.framework` (macOS yerleşik), `networksetup` CLI |

---

## Projemize Destek Olun

Eğer offveil ağ gizliliğinizi korumaya ve tarama deneyiminizi iyileştirmeye katkı sağladıysa, projenin büyümesi için yapabileceğiniz en basit ve etkili şey bu depoyu **Yıldızlamaktır (Star ⭐)**. Bu, projenin görünürlüğünü artırır ve ağ gizliliğine önem veren diğer kullanıcıların aracı keşfetmesine yardımcı olur.

<p align="center">
  <a href="https://github.com/berkaykyb/offveil-macOS/stargazers">
    <img src="https://img.shields.io/github/stars/berkaykyb/offveil-macOS?style=for-the-badge&color=ffcc00&label=%E2%AD%90%20OffVeil'i%20Y%C4%B1ld%C4%B1zla" alt="Star on GitHub" />
  </a>
</p>

---

## Yasal Uyarı

offveil, yerel proxy düzeyinde standart ve kamuya açık TCP/TLS parçalama (fragmentation) tekniklerini uygulayan, genel amaçlı bir ağ gizliliği aracıdır. Trafiğinizi hiçbir üçüncü taraf sunucuya yönlendirmez ve bir VPN servisi değildir.

Kullanıcılar, bu yazılımı kullanırken yürürlükteki yerel mevzuata ve eriştikleri platformların kullanım koşullarına uyma konusunda tamamen kendi sorumluluklarını kabul etmiş sayılır. Geliştirici, yasadışı herhangi bir kullanımı desteklemez veya teşvik etmez.

---

## Teşekkürler ve Lisans

Bu proje **Tüm Hakları Saklıdır (All Rights Reserved)** lisansı altındadır. Kaynak kodu şeffaflık ve eğitim amaçlı olarak GitHub'da herkese açık tutulmaktadır. Yazarın açık yazılı izni olmadan kodu kopyalamak, değiştirmek veya dağıtmak yasaktır. Detaylar için [LICENSE](LICENSE) dosyasına bakabilirsiniz.

OffVeil (macOS) v1.x, temel paket parçalama yetenekleri için açık kaynaklı **[SpoofDPI](https://github.com/xvzc/SpoofDPI)** projesini ([@xvzc](https://github.com/xvzc)) kullanmaktadır. SpoofDPI uygulaması [Apache License 2.0](https://github.com/xvzc/SpoofDPI/blob/main/LICENSE) lisansına sahiptir.

Bu projenin vizyonunu ilk oluşturan takım arkadaşım **[@erayselim](https://github.com/erayselim)**'e özel teşekkürler.

<p align="center">
  <sub>Bağlantınızı koruyoruz. Verilerinizi gizli tutuyoruz.</sub>
</p>
