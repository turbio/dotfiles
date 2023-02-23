# idk dynamic shit is scary. I just want everyone to talk.
{
  vpn = {
    hosts = {
      balrog = {
        ip = "10.100.0.1";
        pubkey = "z8vFtmrdwBEFTe49UykBbz9sQS8XvoDBGcsf/7dZ9R8=";
        endpoint = "turb.io";
      };
      gero = {
        ip = "10.100.0.3";
        pubkey = "6QkyXbJ4orCVjGlw03Aa0R1GeUiEoalVdWCAxQH6Qkw=";
      };
      panda = {
        ip = "10.100.0.2";
        pubkey = "z1UuGW920g/LWz0NjlmpFdZIk5l4cV9AM1x6758kkFg=";
      };
      itoh = {
        ip = "10.100.0.4";
        pubkey = "n6kLi/GHTRo8w+TNLcT7YxBxAkIJss1QYfn6VHt5dGI=";
      };
      malco = {
        ip = "10.100.0.5";
        pubkey = "7jaOhTtxY+ir0YCf+FaYv1w6RIh7TtUtF0rnvhl1BFE=";
      };
      pando = {
        ip = "10.100.0.6";
        pubkey = "Y9TKTr/fVYVxogi9vYYKo/xFjUk2Z5XFRuEdkSDN7yI=";
      };
    };

    subnet = "10.100.0.0/24";
  };

  sshkeys = {
    yubi = "sk-ecdsa-sha2-nistp256@openssh.com AAAAInNrLWVjZHNhLXNoYTItbmlzdHAyNTZAb3BlbnNzaC5jb20AAAAIbmlzdHAyNTYAAABBBBa1RGmSWCA4xvw+sBZglCwjMbJ7QtYszwR3agccvse+VMq+tCOcPFUCNi5Wt36IJa9dBNbRHihE1KbaX5pGptwAAAAEc3NoOg== turbio@turb.io";
    gero = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDDgxXG3UWBS9WquGteKDQvXlhtiD+ERyd765Tj6NdKgpy6HDgyObzC6pn/ngt4GH3x8ZsXYrgEI/j/Ti0362BtmxDr/LdNNToBJEN4Rab/5x4ne/4f4UQdLcNqCSddXRP210LYpBdyPA1G0rwBzipw3wyCCAAoLLxaKcjAHB7MREqHf3Sl9AHnMQupIylZ9xnuXZZdX2VieFMAlMubHR2l3Lz+pSZ8xWh9lbxmVOCGqRWbzg5kNEWxNmH/nKGukmj+Lj/+SmktmHCita1gGWii+ogzHP9HQZzpDVeOoYLfeag9FEzV+EpAvcno0Yzk2s0wpVLUIxmJMp+n4aC26t+9VSHACMslddaOVgkhsK8k1Hqj0cfugLi5Q6zXzCT/eXPT7HwywcDXJisCoffk8OM4TVcVHT4Kjs44ZiU+VBdKkrmDcNa5YFMxGcaUA9R+AnLsjOtLQQgL4PuWWh1E5W2yojKrjbd1zZZwo+TI8vAU7gJDhN//9e+jQsCJtU3EpWc= turbio@gero";
    balrog = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDorDxQDVtTWpD1IrVjB0v/+LZ33B1e9ktYuneIl1AvnqlZ6s/+CZNrFLJk9HW2POYzpUaSUPZpdFtzjqLmgPmnC8gTVJk9pGXQ0jRqAU+YtppqMir4/ZzO7KReVv2kDYGAv3DFr8DX8q1GUGw4hAQbbpEsNdSoEDvKKvV0b3GPuRgpKzP/LQ7Gl5IvxaQGk32BjyGIywh2/R4SeYiO0xGn09DM/MSXojVeEnP5NAMOZjCqcLZbf4k0Uf570SGGWJWld+leJ/w2YzTfkENgw6YaZMIu+F0xxRsDJMNqQbZqhzTqKGR0162Gc7m5ZGxZx3e/hzH/6eSjnoBdTL/LUK30kkn2umIXmIS9eeAiRkUEOoR6oKAX+tHKFYcKUXiD5WYiKGOQfz88XOuQDaWPXpBDG45qtwS2+BsneELqGBYB6uymjhr2BcRwgnal+vXGMmzXIRrWniIzM0/D7PQ79s7ifODqVDTSd+NT9tf/oksUNbvIATyirUsariN9oZX13IE= turbio@balrog";
    panda = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCz1+FuN6wuKdX9GfdKfXgZ6FmnsaiDHtJI1/4pYOU6Tx+E1kuHEbEcAqBxTQ6oBw+iRDDohoTbSO90HFMePNYUxN2KR343vklWKglNqJG35SjL/m7R5uMhNqmmOk6Le/r577hrSOKSdhcvc3Pb7VD3DeaN2x8RbRrL55Q8Sfv4YSAYzKW6Cr8dFhjJSZF+1+wyWADkn1IXRm+KAMsAAOLT09nCm/ZODTINBPqbrQLor5P7SyZOoL2/f2aYU82V1H/p+xHTqgRzyCI2erSGxSQzUkZpJoVIegYUMrQWedHwKL0nxX5CU++lU+EYi9Pp3ysj0lscjAQLV1Fv+mZc3blgECYo18lth7d95WK88K7KLSrxaW/pYQuCZxQdqG5+NL5Tw0ZIA7TObin2mme+xBcrwdSySTZh1WCKrqyzncZySgLz1RXMKJEM48J0/F+bxG72CYhlP8RrluymZt1XbwKTSP/XwF5hFuWyVO/DO34dioySCYRqkDdgkUHuG9WP0Lc= turbio@panda";
    pando = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCfiYFkPl3xMbbNP3LO4HwwonrxSgyX8xKKNuiz56BzaLFTWz6pOUN2LfyCFYNNEHg33Gj1sxU1YAlbDd8+IbXI/6Isc8RT88HVwqKv1qzPGUm9MaUsugJClCOOFeyW1Gnu4JHxpnSE8TFU+vc9TNzVBp2QaBhKW11z/nwpqBdtUSkKzaQ5hTIedWf8cLsFDiax/fGb5B1TqqevDhBB3Lf1FJKov633EmQdnb9AUjA8DWHZqcvsxQkWZ3NKDK+aMva7j8ChpVn7AsYwCLMofphQTOYcn+Yd4ilM2r1UwIIepx/zk0z/GQpYzzVDEYWkEbgmcuxWZea8n4vsjHGHrd3eplfv/4iaMP//aw/O2ernzlgxvD8YRO5ix8RtXF+NqorU0YVrTWMV5zQFHuyJyRDespa+xAQf4rzxqtyCNQLRia8LKnqAbF29hQWJ49hDWqvxuew2NGR5h865NATDBkam94F2vUWT40tRie47HlVKFxmC7fFeRVwMOT/olROTK+k= turbio@pando";  
  };
}
