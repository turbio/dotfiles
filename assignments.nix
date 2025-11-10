# idk dynamic shit is scary. I just want everyone to talk.
{
  vpn = {
    hosts = {
      balrog = {
        ip = "10.100.0.1";
        pubkey = "z8vFtmrdwBEFTe49UykBbz9sQS8XvoDBGcsf/7dZ9R8=";
        endpoint = "gateway.turb.io";
        router = true;
      };
      gero = {
        ip = "10.100.0.3";
        pubkey = "6QkyXbJ4orCVjGlw03Aa0R1GeUiEoalVdWCAxQH6Qkw=";
      };
      curly = {
        ip = "10.100.0.2";
        pubkey = "yrP2YV5L1LE4Frmf0IkbvVvtdZZuMuRMVbHsE06k9GI=";
      };
      itoh = {
        ip = "10.100.0.4";
        pubkey = "nl9gri7OsWGYWj+LbbtUBv8dKxFVOz4wlunm7dUhAgk=";
      };
      star = {
        ip = "10.100.0.5";
        pubkey = "lfUVvROJvEyOHlzBxWsEpp7rWvY0Pt9J7cTKsPra92w=";
      };
      pando = {
        ip = "10.100.0.6";
        pubkey = "Y9TKTr/fVYVxogi9vYYKo/xFjUk2Z5XFRuEdkSDN7yI=";
      };
      ios = {
        ip = "10.100.0.7";
        pubkey = "8RPnvY0Vy641THmmnkGiz37oN65VGKplEZkOKuUqly8=";
      };
      ballos = {
        ip = "10.100.0.10";
        pubkey = "7u9v3uGkvTY0fAZwz1ACMHSHyD+ocPXFrccDSuPPzUQ=";
      };
    };

    #subnet = "10.100.0.0/24";
    subnet = "100.64.0.0/10"; # cgnat
    internal = "100.100.0.0/16";
  };

  sshkeys = {
    gero = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDDgxXG3UWBS9WquGteKDQvXlhtiD+ERyd765Tj6NdKgpy6HDgyObzC6pn/ngt4GH3x8ZsXYrgEI/j/Ti0362BtmxDr/LdNNToBJEN4Rab/5x4ne/4f4UQdLcNqCSddXRP210LYpBdyPA1G0rwBzipw3wyCCAAoLLxaKcjAHB7MREqHf3Sl9AHnMQupIylZ9xnuXZZdX2VieFMAlMubHR2l3Lz+pSZ8xWh9lbxmVOCGqRWbzg5kNEWxNmH/nKGukmj+Lj/+SmktmHCita1gGWii+ogzHP9HQZzpDVeOoYLfeag9FEzV+EpAvcno0Yzk2s0wpVLUIxmJMp+n4aC26t+9VSHACMslddaOVgkhsK8k1Hqj0cfugLi5Q6zXzCT/eXPT7HwywcDXJisCoffk8OM4TVcVHT4Kjs44ZiU+VBdKkrmDcNa5YFMxGcaUA9R+AnLsjOtLQQgL4PuWWh1E5W2yojKrjbd1zZZwo+TI8vAU7gJDhN//9e+jQsCJtU3EpWc= turbio@gero";
    balrog = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDorDxQDVtTWpD1IrVjB0v/+LZ33B1e9ktYuneIl1AvnqlZ6s/+CZNrFLJk9HW2POYzpUaSUPZpdFtzjqLmgPmnC8gTVJk9pGXQ0jRqAU+YtppqMir4/ZzO7KReVv2kDYGAv3DFr8DX8q1GUGw4hAQbbpEsNdSoEDvKKvV0b3GPuRgpKzP/LQ7Gl5IvxaQGk32BjyGIywh2/R4SeYiO0xGn09DM/MSXojVeEnP5NAMOZjCqcLZbf4k0Uf570SGGWJWld+leJ/w2YzTfkENgw6YaZMIu+F0xxRsDJMNqQbZqhzTqKGR0162Gc7m5ZGxZx3e/hzH/6eSjnoBdTL/LUK30kkn2umIXmIS9eeAiRkUEOoR6oKAX+tHKFYcKUXiD5WYiKGOQfz88XOuQDaWPXpBDG45qtwS2+BsneELqGBYB6uymjhr2BcRwgnal+vXGMmzXIRrWniIzM0/D7PQ79s7ifODqVDTSd+NT9tf/oksUNbvIATyirUsariN9oZX13IE= turbio@balrog";
    pando = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCfiYFkPl3xMbbNP3LO4HwwonrxSgyX8xKKNuiz56BzaLFTWz6pOUN2LfyCFYNNEHg33Gj1sxU1YAlbDd8+IbXI/6Isc8RT88HVwqKv1qzPGUm9MaUsugJClCOOFeyW1Gnu4JHxpnSE8TFU+vc9TNzVBp2QaBhKW11z/nwpqBdtUSkKzaQ5hTIedWf8cLsFDiax/fGb5B1TqqevDhBB3Lf1FJKov633EmQdnb9AUjA8DWHZqcvsxQkWZ3NKDK+aMva7j8ChpVn7AsYwCLMofphQTOYcn+Yd4ilM2r1UwIIepx/zk0z/GQpYzzVDEYWkEbgmcuxWZea8n4vsjHGHrd3eplfv/4iaMP//aw/O2ernzlgxvD8YRO5ix8RtXF+NqorU0YVrTWMV5zQFHuyJyRDespa+xAQf4rzxqtyCNQLRia8LKnqAbF29hQWJ49hDWqvxuew2NGR5h865NATDBkam94F2vUWT40tRie47HlVKFxmC7fFeRVwMOT/olROTK+k= turbio@pando";
  };
}
