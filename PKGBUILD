pkgname=android-studio-alex
pkgver=2024.2.1.12
pkgrel=1
pkgdesc="The official Android IDE (Stable branch)"
arch=('i686' 'x86_64')
url="https://developer.android.com/"
license=('APACHE')
makedepends=()
depends=('alsa-lib' 'freetype2' 'libxrender' 'libxtst' 'which')
optdepends=('gtk2: GTK+ look and feel'
            'libgl: emulator support'
            'ncurses5-compat-libs: native debugger support')
options=('!strip')
source=("https://dl.google.com/dl/android/studio/ide-zips/$pkgver/android-studio-$pkgver-linux.tar.gz"
        "$pkgname.desktop"
        "license.html")
sha256sums=('4df51ac7d73e45203383418a537c9562c58bef6ab80d4074cd98acb387e5caa6'
            '51eb6978307c0785808758e174c024a82523ec1d6a5c9b8354f446467065caa6'
            '9a7563f7fb88c9a83df6cee9731660dc73a039ab594747e9e774916275b2e23e')

if [ "$CARCH" = "i686" ]; then
    depends+=('java-environment')
fi

package() {
  cd $srcdir/android-studio
  # Install the application
  install -d $pkgdir/{opt/android-studio,usr/bin}
  cp -a bin lib jbr plugins license LICENSE.txt build.txt product-info.json $pkgdir/opt/android-studio
  ln -s /opt/android-studio/bin/studio $pkgdir/usr/bin/$pkgname
  # Copy licenses
  install -Dm644 LICENSE.txt "${pkgdir}/usr/share/licenses/${pkgname}/LICENSE.txt"
  install -Dm644 $srcdir/license.html "${pkgdir}/usr/share/licenses/${pkgname}/license.html"
  # Add the icon and desktop file
  install -Dm644 bin/studio.png $pkgdir/usr/share/pixmaps/$pkgname.png
  install -Dm644 $srcdir/$pkgname.desktop $pkgdir/usr/share/applications/$pkgname.desktop
  chmod -R ugo+rX $pkgdir/opt
}
