/*
 * Copyright (C) 2014 Cloudius Systems, Ltd.
 */

#ifndef TEMPORARY_BUFFER_HH_
#define TEMPORARY_BUFFER_HH_

#include "deleter.hh"
#include "util/eclipse.hh"

// A temporary_buffer either points inside a larger buffer, or, if the requested size
// is too large, or if the larger buffer is scattered, contains its own storage.
template <typename CharType>
class temporary_buffer {
    static_assert(sizeof(CharType) == 1, "must buffer stream of bytes");
    CharType* _buffer;
    size_t _size;
    std::unique_ptr<deleter> _deleter;
public:
    explicit temporary_buffer(size_t size)
        : _buffer(new CharType[size]), _size(size), _deleter(new internal_deleter(nullptr, _buffer, size)) {}
    //explicit temporary_buffer(CharType* borrow, size_t size) : _buffer(borrow), _size(size) {}
    temporary_buffer() = delete;
    temporary_buffer(const temporary_buffer&) = delete;
    temporary_buffer(temporary_buffer&& x) : _buffer(x._buffer), _size(x._size), _deleter(std::move(x._deleter)) {
        x._buffer = nullptr;
        x._size = 0;
    }
    temporary_buffer(CharType* buf, size_t size, std::unique_ptr<deleter> d)
        : _buffer(buf), _size(size), _deleter(std::move(d)) {}
    void operator=(const temporary_buffer&) = delete;
    temporary_buffer& operator=(temporary_buffer&& x) {
        if (this != &x) {
            _buffer = x._buffer;
            _size = x._size;
            _deleter = std::move(x._deleter);
            x._buffer = nullptr;
            x._size = 0;
        }
        return *this;
    }
    const CharType* get() const { return _buffer; }
    CharType* get_write() { return _buffer; }
    size_t size() const { return _size; }
    const CharType* begin() { return _buffer; }
    const CharType* end() { return _buffer + _size; }
    bool owning() const {
        return _deleter && dynamic_cast<internal_deleter*>(_deleter.get());
    }
    temporary_buffer prefix(size_t size) RREF {
        auto ret = std::move(*this);
        ret._size = size;
        return ret;
    }
    CharType operator[](size_t pos) const {
        return _buffer[pos];
    }
    bool empty() const { return !size(); }
    temporary_buffer share() {
        auto d = ::share(_deleter);
        return temporary_buffer(_buffer, _size, std::move(d));
    }
    temporary_buffer share(size_t pos, size_t len) {
        auto ret = share();
        ret._buffer += pos;
        ret._size = len;
        return ret;
    }
    void trim_front(size_t pos) {
        _buffer += pos;
        _size -= pos;
    }
    void trim(size_t pos) {
        _size = pos;
    }
};

#endif /* TEMPORARY_BUFFER_HH_ */
