{
  description = "開発環境 - Bun + Zenn CLI";
  
  inputs = {
    # 最新のnixpkgsを使用
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };
  
  outputs = { self, nixpkgs }:
    let
      # サポートするシステム（Linux/Mac両対応）
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      
      # 各システムでflakeを生成
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      devShells = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            name = "bun-zenn-dev-environment";
            
            # 使いたいパッケージたち
            buildInputs = with pkgs; [
              bun        # 高速なJavaScript/TypeScript実行環境
              # nodejs     # Node.js（念のため）
              # Zenn CLIはnpmでインストールする方が確実
            ];
            
            # 環境に入ったときに実行されるコマンド
            shellHook = ''
              echo "🎉 Bun + Zenn CLI 開発環境にようこそ！"
              echo ""
              echo "📦 インストール済み:"
              echo "  - Bun: $(bun --version)"
              echo "  - Node.js: $(node --version)"
              echo ""
              echo "🛠️  Zenn CLIをインストールするには:"
              echo "  bun add -g @zenn-dev/zenn-cli"
              echo ""
              echo "🚀 Zennの記事を作成するには:"
              echo "  bunx zenn new:article"
              echo ""
              echo "📝 Zennプレビューを開始するには:"
              echo "  bunx zenn preview"
              echo ""
            '';
            
          };
        });
    };
}