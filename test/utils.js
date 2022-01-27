const BigNumber = require('bignumber.js');
//自定义工具类
function MyUtil(){
    this.hexToNum = function (str){
        if(str.substring(0,2).toLowerCase() != "0x"){
            str = "0x"+str;
        }
        return new BigNumber(str).toNumber();
    }
    this.numToHex = function (number){
        let str = new BigNumber(number).toString(16)
        if(str.length%2!=0){
            str = "0"+str;
        }
        return "0x"+str;
    }
    this.hexToStr = function (str) {
        if(str.substring(0,2).toLowerCase()=="0x"){
            str = str.substring(2);
        }
        var buf = [];
        for (var i = 0; i < str.length; i += 2) {
            buf.push(parseInt(str.substring(i, i + 2), 16));
        }
        return this.readUTF(buf);
    }
    this.strToHex = function (str) {
        var charBuf = this.writeUTF(str, true);
        var re = '';
        for (var i = 0; i < charBuf.length; i++) {
            var x = (charBuf[i] & 0xFF).toString(16);
            if (x.length === 1) {
                x = '0' + x;
            }
            re += x;
        }
        return "0x"+re;
    }
    this.writeUTF = function (str, isGetBytes) {
        var back = [];
        var byteSize = 0;
        for (var i = 0; i < str.length; i++) {
            var code = str.charCodeAt(i);
            if (0x00 <= code && code <= 0x7f) {
                byteSize += 1;
                back.push(code);
            } else if (0x80 <= code && code <= 0x7ff) {
                byteSize += 2;
                back.push((192 | (31 & (code >> 6))));
                back.push((128 | (63 & code)))
            } else if ((0x800 <= code && code <= 0xd7ff) || (0xe000 <= code && code <= 0xffff)) {
                byteSize += 3;
                back.push((224 | (15 & (code >> 12))));
                back.push((128 | (63 & (code >> 6))));
                back.push((128 | (63 & code)))
            }
        }
        for (i = 0; i < back.length; i++) {
            back[i] &= 0xff;
        }
        if (isGetBytes) {
            return back
        }
        if (byteSize <= 0xff) {
            return [ 0, byteSize ].concat(back);
        } else {
            return [ byteSize >> 8, byteSize & 0xff ].concat(back);
        }
    }
    this.readUTF = function (arr) {
        if (typeof arr === 'string') {
            return arr;
        }
        var UTF = '', _arr = arr;
        for (var i = 0; i < _arr.length; i++) {
            var one = _arr[i].toString(2), v = one.match(/^1+?(?=0)/);
            if (v && one.length == 8) {
                var bytesLength = v[0].length;
                var store = _arr[i].toString(2).slice(7 - bytesLength);
                for (var st = 1; st < bytesLength; st++) {
                    store += _arr[st + i].toString(2).slice(2)
                }
                UTF += String.fromCharCode(parseInt(store, 2));
                i += bytesLength - 1
            } else {
                UTF += String.fromCharCode(_arr[i])
            }
        }
        return UTF
    }
    this.generateId = function (){
        return new Date().getTime() + parseInt(Math.random() * 1000000);
    }
}

exports.MyUtil = MyUtil;
