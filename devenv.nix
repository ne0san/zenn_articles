{ pkgs, ... }:

{
  languages.javascript = {
    enable = true;
    package = pkgs.bun;
  };

  # パッケージ追加
  packages = with pkgs; [
    bun
    git
  ];

  # シェル起動時のメッセージ
  enterShell = ''
    echo "zenn記事環境"
    echo "Bun: $(bun --version)"
    echo ""
    echo "クイックスタート:"
    echo "  bunx zenn preview     - 記事プレビュー"
    echo "  bunx zenn new:article - 新記事作成"
  '';
}