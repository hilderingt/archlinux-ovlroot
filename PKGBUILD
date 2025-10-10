# Copyright 2025 Tim Hildering

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# Maintainer: Tim Hildering <hilderingt@posteo.net>

pkgname=archlinux-ovlroot
pkgver=1.0.0
pkgrel=1
pkgdesc="Overlay the root filesystem with a tmpfs filesystem."
arch=('any')
url="https://github.com/hilderingt/archlinux-ovlroot"
license=('GPLv3')
depends=(
  'mkinitcpio'
)
source=(
  'install.sh'
  'hook.sh'
  'mount.ovlroot'
  'ovlroot.sh'
)
sha256sums=(
  'SKIP'
  'SKIP'
  'SKIP'
  'SKIP'
)

build() {
  :
}

package() {
  install -Dm644 "$srcdir/install.sh" "$pkgdir/usr/lib/initcpio/install/ovlroot"
  install -Dm644 "$srcdir/hook.sh" "$pkgdir/usr/lib/initcpio/hooks/ovlroot"
  install -Dm755 "$srcdir/mount.ovlroot" "$pkgdir/usr/bin/mount.ovlroot"
  mkdir -p "$pkgdir/usr/share/ovlroot"
  install -Dm644 "$srcdir/ovlroot.sh" "$pkgdir/usr/share/ovlroot/ovlroot.sh"
  mkdir -p "$pkgdir/etc/ovlroot.d"
}