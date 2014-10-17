/*
 * Copyright (C) 2014 Cloudius Systems, Ltd.
 */

#include "core/ragel.hh"
#include <memory>
#include <algorithm>
#include <functional>

%%{

machine memcache_ascii_protocol;

access _fsm_;

action mark {
    g.mark_start(p);
}

action start_blob {
    g.mark_start(p);
    _size_left = _size;
}

action advance_blob {
    auto len = std::min((uint32_t)(pe - p), _size_left);
    _size_left -= len;
    p += len;
    if (_size_left == 0) {
        _blob = str();
        p--;
        fret;
    }
    p--;
}

crlf = '\r\n';
sp = ' ';
u32 = digit+ >{ _u32 = 0; } ${ _u32 *= 10; _u32 += fc - '0'; };
u64 = digit+ >{ _u64 = 0; } ${ _u64 *= 10; _u64 += fc - '0'; };
key = [^ ]+ >mark %{ _key = str(); };
flags = u32 %{ _flags = _u32; };
expiration = u32 %{ _expiration = _u32; };
size = u32 %{ _size = _u32; };
blob := any+ >start_blob $advance_blob;
maybe_noreply = (sp "noreply" @{ _noreply = true; })? >{ _noreply = false; };
maybe_expiration = (sp expiration)? >{ _expiration = 0; };
version_field = u64 %{ _version = _u64; };

insertion_params = sp key sp flags sp expiration sp size maybe_noreply (crlf @{ fcall blob; } ) crlf;
set = "set" insertion_params @{ _state = state::cmd_set; };
add = "add" insertion_params @{ _state = state::cmd_add; };
replace = "replace" insertion_params @{ _state = state::cmd_replace; };
cas = "cas" sp key sp flags sp expiration sp size sp version_field maybe_noreply (crlf @{ fcall blob; } ) crlf @{ _state = state::cmd_cas; };
get = "get" (sp key %{ _keys.push_back(std::move(_key)); })+ crlf @{ _state = state::cmd_get; };
gets = "gets" (sp key %{ _keys.push_back(std::move(_key)); })+ crlf @{ _state = state::cmd_gets; };
delete = "delete" sp key maybe_noreply crlf @{ _state = state::cmd_delete; };
flush = "flush_all" maybe_expiration maybe_noreply crlf @{ _state = state::cmd_flush_all; };
version = "version" crlf @{ _state = state::cmd_version; };
stats = "stats" crlf @{ _state = state::cmd_stats; };
main := (add | replace | set | get | gets | delete | flush | version | cas | stats) >eof{ _state = state::eof; };

prepush {
    prepush();
}

postpop {
    postpop();
}

}%%

class memcache_ascii_parser : public ragel_parser_base<memcache_ascii_parser> {
    %% write data nofinal noprefix;
public:
    enum class state {
        error,
        eof,
        cmd_set,
        cmd_cas,
        cmd_add,
        cmd_replace,
        cmd_get,
        cmd_gets,
        cmd_delete,
        cmd_flush_all,
        cmd_version,
        cmd_stats,
    };
    state _state;
    uint32_t _u32;
    uint64_t _u64;
    sstring _key;
    uint32_t _flags;
    uint32_t _expiration;
    uint32_t _size;
    uint32_t _size_left;
    uint64_t _version;
    sstring _blob;
    bool _noreply;
    std::vector<sstring> _keys;
public:
    void init() {
        init_base();
        _state = state::error;
        _keys.clear();
        %% write init;
    }

    char* parse(char* p, char* pe, char* eof) {
        sstring_builder::guard g(_builder, p, pe);
        auto str = [this, &g, &p] { g.mark_end(p); return get_str(); };
        %% write exec;
        if (_state != state::error) {
            return p;
        }
        if (p != pe) {
            p = pe;
            return p;
        }
        return nullptr;
    }
    bool eof() const {
        return _state == state::eof;
    }
};
