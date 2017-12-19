function fish_user_key_bindings
    fzf_key_bindings

    bind --mode insert \ch backward-char
    bind --mode insert \cj down-or-search
    bind --mode insert \ck up-or-search
    bind --mode insert \cl forward-char
end
