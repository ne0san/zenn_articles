---
title: "MacのVSCode上のターミナルからnixを使用できない問題の原因と解決"
emoji: "🫥"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["nix", "mac", "vscode"]
published: true
---

Mac で[nix](https://nixos.org)を試そうと色々いじっていたところ、

通常のターミナルでは動作するのに VSCode 上のターミナルで nix 関連コマンドが実行できない謎現象に遭遇しました。

```zsh
> nix
zsh: correct 'nix' to 'mix' [nyae]? n
zsh: command not found: nix # nix-shellも同様
```

Claude 頼りで原因を調べていたところ、複数の条件が絡まったレアケースに引っかかっていたことが判明しました。
原因と解決策を共有します。

# 解決策

mac で zsh を使用している場合、以下のいずれかで解決できます

- 【推奨】`~/.zprofile`などの zsh 設定ファイル上にある`PATH`を上書きしている設定を削除
- VSCode の`settings.json`に以下のいずれかの設定を追加
  - `"terminal.integrated.inheritEnv": false`
  - `"terminal.integrated.env.osx": { "__ETC_PROFILE_NIX_SOURCED": "" }`

# 原因

少々複雑なため、段階を追って説明します。

## 1. 公式インストーラ(https://nixos.org/nix/install)で nix をマルチユーザーインストールする

- `/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh`が作成される
  - 一言で説明すると`__ETC_PROFILE_NIX_SOURCED`が設定されていない場合に以下を行うスクリプトです
    - `__ETC_PROFILE_NIX_SOURCED`を`1`に設定
    - `PATH`に nix のパスを含める

:::details `/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh`の内容

```sh:/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
# Only execute this file once per shell.
# This file is tested by tests/installer/default.nix.
if [ -n "${__ETC_PROFILE_NIX_SOURCED:-}" ]; then return; fi
export __ETC_PROFILE_NIX_SOURCED=1

NIX_LINK=$HOME/.nix-profile
if [ -n "${XDG_STATE_HOME-}" ]; then
    NIX_LINK_NEW="$XDG_STATE_HOME/nix/profile"
else
    NIX_LINK_NEW=$HOME/.local/state/nix/profile
fi
if [ -e "$NIX_LINK_NEW" ]; then
    if [ -t 2 ] && [ -e "$NIX_LINK" ]; then
        warning="\033[1;35mwarning:\033[0m"
        printf "$warning Both %s and legacy %s exist; using the former.\n" "$NIX_LINK_NEW" "$NIX_LINK" 1>&2
        if [ "$(realpath "$NIX_LINK")" = "$(realpath "$NIX_LINK_NEW")" ]; then
            printf "         Since the profiles match, you can safely delete either of them.\n" 1>&2
        else
            # This should be an exceptionally rare occasion: the only way to get it would be to
            # 1. Update to newer Nix;
            # 2. Remove .nix-profile;
            # 3. Set the $NIX_LINK_NEW to something other than the default user profile;
            # 4. Roll back to older Nix.
            # If someone did all that, they can probably figure out how to migrate the profile.
            printf "$warning Profiles do not match. You should manually migrate from %s to %s.\n" "$NIX_LINK" "$NIX_LINK_NEW" 1>&2
        fi
    fi
    NIX_LINK="$NIX_LINK_NEW"
fi

export NIX_PROFILES="/nix/var/nix/profiles/default $NIX_LINK"

# Populate bash completions, .desktop files, etc
if [ -z "${XDG_DATA_DIRS-}" ]; then
    # According to XDG spec the default is /usr/local/share:/usr/share, don't set something that prevents that default
    export XDG_DATA_DIRS="/usr/local/share:/usr/share:$NIX_LINK/share:/nix/var/nix/profiles/default/share"
else
    export XDG_DATA_DIRS="$XDG_DATA_DIRS:$NIX_LINK/share:/nix/var/nix/profiles/default/share"
fi

# Set $NIX_SSL_CERT_FILE so that Nixpkgs applications like curl work.
if [ -n "${NIX_SSL_CERT_FILE:-}" ]; then
    : # Allow users to override the NIX_SSL_CERT_FILE
elif [ -e /etc/ssl/certs/ca-certificates.crt ]; then # NixOS, Ubuntu, Debian, Gentoo, Arch
    export NIX_SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
elif [ -e /etc/ssl/ca-bundle.pem ]; then # openSUSE Tumbleweed
    export NIX_SSL_CERT_FILE=/etc/ssl/ca-bundle.pem
elif [ -e /etc/ssl/certs/ca-bundle.crt ]; then # Old NixOS
    export NIX_SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt
elif [ -e /etc/pki/tls/certs/ca-bundle.crt ]; then # Fedora, CentOS
    export NIX_SSL_CERT_FILE=/etc/pki/tls/certs/ca-bundle.crt
else
  # Fall back to what is in the nix profiles, favouring whatever is defined last.
  check_nix_profiles() {
    if [ -n "${ZSH_VERSION:-}" ]; then
      # Zsh by default doesn't split words in unquoted parameter expansion.
      # Set local_options for these options to be reverted at the end of the function
      # and shwordsplit to force splitting words in $NIX_PROFILES below.
      setopt local_options shwordsplit
    fi
    for i in $NIX_PROFILES; do
      if [ -e "$i/etc/ssl/certs/ca-bundle.crt" ]; then
        export NIX_SSL_CERT_FILE=$i/etc/ssl/certs/ca-bundle.crt
      fi
    done
  }
  check_nix_profiles
  unset -f check_nix_profiles
fi

export PATH="$NIX_LINK/bin:/nix/var/nix/profiles/default/bin:$PATH"
unset NIX_LINK NIX_LINK_NEW
```

:::

- `/etc/zshrc`に以下が追加される

```zsh:/etc/zshrc
if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
  . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
fi
```

## 2. `~/.zprofile`などに`PATH`を上書きする設定が含まれている

私の環境の場合、`~/.zprofile`に元のパスを無視して上書きする設定が含まれていました。

```sh:.zprofile
export PATH=/Users/my_name/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/share/dotnet:/opt/X11/bin:~/.dotnet/tools:/Library/Apple/usr/bin:/Library/Frameworks/Mono.framework/Versions/Current/Commands:/Users/my_name/Library/Android/sdk/emulator:/Users/my_name/Library/Android/sdk/platform-tools
```

内容的におそらく 5 年以上前にインストールした Visual Studio for Mac、 XQuartz、Android Studio あたりが犯人かと。

学生時代から Mac 乗り換え時に毎回 TimeMachine でバックアップ&復元していたのが災いしました 🫠

## 3. 1.&2. 両方満たす条件下で VSCode 上のターミナルを起動

Windows 以外の VSCode は起動時、`--force-user-env`というフラグ(デフォルトで on)により、内部的に一度ターミナルを起動し、すべての環境変数を取得します。

VSCode 内でターミナルを起動した場合、1.で取得した環境変数をすべて引き継いだ上で`~/.zshrc`,`~/.zprofile`などの設定ファイルが再度読み込まれる (`"terminal.integrated.inheritEnv": false`により VSCode 本体の環境変数を無視してターミナル起動もできます)

この結果、VSCode 上では以下の流れで nix 関連のパスが含まれないターミナルが起動してしまいます。

1. `.zprofile`により`PATH`が nix 関連を含まないものに上書きされる
2. `__ETC_PROFILE_NIX_SOURCED`が`1`のまま`/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh`が実行される。当該スクリプトの nix 関連パスを追加する処理がスキップ

# 雑まとめ

- シェルの設定ファイルは見直そう!!!
- シェルの設定で`PATH`を上書きするな!!!!!

# 参考文献

https://stackoverflow.com/questions/67429673/nix-on-vscode-terminal
https://stackoverflow.com/questions/48595446/is-there-any-way-to-set-environment-variables-in-visual-studio-code
