{
  nixpkgs.overlays = [
    (final: prev: {
      gixy = prev.gixy.overrideAttrs (old: {
        patches = [
          (final.fetchpatch2 {
            url = "https://github.com/yandex/gixy/compare/6f68624a7540ee51316651bda656894dc14c9a3e...b1c6899b3733b619c244368f0121a01be028e8c2.patch";
            hash = "sha256-jAF5WxMwTKTiCvEQF2xQnTBp6S2Yzpgq6mPugVKQksM=";
          })
        ]
        ++ builtins.tail old.patches;
      });
    })
  ];
}
