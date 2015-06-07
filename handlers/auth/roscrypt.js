module.exports = function(baseSecret)
{
	function encryptUserAgent(ua)
	{
		var buf = new Buffer(4 + ua.length);

		buf.writeUInt32LE(0xCDCDCDCD, 0);

		for (var i = 0; i < ua.length; i++)
		{
			buf.writeUInt8(ua.charCodeAt(i) ^ 0xCD, i + 4);
		}

		return buf.toString('base64');
	}

	function deriveKey1(keyBase, length)
	{
		var realKeyBase = keyBase;

		var buf = new Buffer(258);

		// set first two bytes to 0
		buf.writeUInt16LE(0, 0);

		// write a byte for every remaining byte
		for (var i = 0; i < 256; i++)
		{
			buf.writeUInt8(i, i + 2);
		}

		// start the big bad loop
		var j = 2;
		var preByte = 0;

		while (j < 258)
		{
			var inner = -2;

			for (var k = j; k < j + 4; k++)
			{
				var bk = k - 2;

				var a = buf.readUInt8(k);
				var b = (a + realKeyBase.readUInt8(bk % length) + preByte) % 256;
				var c = (2 + b) % 258;

				buf.writeUInt8(buf.readUInt8(c), k);
				buf.writeUInt8(a, c);

				preByte = b;

				inner++;
			}

			j += 4;
		}

		return buf;
	}

	function deriveKey2(keyBuf, keyBit, length)
	{
		var buf = new Buffer(length);

		for (var i = 0; i < length; i++)
		{
			var idx = (keyBuf.readUInt8(0) + 1) % 256;

			keyBuf.writeUInt8(idx, 0);

			var a = idx + 2;
			var b = keyBuf.readUInt8(a);
			var x = (keyBuf.readUInt8(1) + b) % 256;

			keyBuf.writeUInt8(x, 1);

			var y = keyBuf.readUInt8(x + 2);

			keyBuf.writeUInt8(y, a);
			keyBuf.writeUInt8(b, x + 2);

			var by = keyBit.readUInt8(i);

			by ^= (keyBuf.readUInt8(((keyBuf.readUInt8(a) + keyBuf.readUInt8(x + 2)) % 256) + 2));

			buf.writeUInt8(by, i)
		}

		return buf;
	}

	var g_secret = baseSecret;

	function getBaseKey(type)
	{
		var secretBuf = new Buffer(g_secret, 'base64');
		var tempKeyBuf = deriveKey1(secretBuf.slice(1), 32);

		var keyBit = (!type) ? secretBuf.slice(33, 49) : secretBuf.slice(49, 65);

		keyBit = deriveKey2(tempKeyBuf, keyBit, 16);

		return keyBit;
	}

	var crypto = require('crypto');
	var buffertools = require('buffertools')

	function getMessageDigest(data, key, clientBit, sessionKey)
	{
			// compute base hash
			var hash = crypto.createHash('sha1');

			if (sessionKey)
			{
				var keyBit = sessionKey;

				hash = crypto.createHmac('sha1', keyBit);
			}

			if (clientBit)
			{
				hash.update(clientBit);
			}

			hash.update(data);
			hash.update(key);

			hash = hash.digest();

			return hash;
	}

	function decrypt(packet, client, sessionKey)
	{
		var keyBit = getBaseKey(false);

		if (sessionKey)
		{
			var newKey = new Buffer(16);

			for (var i = 0; i < 16; i++)
			{
				newKey.writeUInt8(keyBit.readUInt8(i) ^ sessionKey.readUInt8(i), i);
			}

			keyBit = newKey;
		}

		var packetKeyOld = packet.slice(0, 16);
		var packetKey = new Buffer(16);

		for (var i = 0; i < 16; i++)
		{
			var b = packetKeyOld.readUInt8(i);

			b ^= keyBit.readUInt8(i % 16);

			packetKey.writeUInt8(b, i);
		}

		var keyBitVer = getBaseKey(true);

		var tkb2 = deriveKey1(packetKey, 16);

		var blockSize, dataSeg;

		if (!client)
		{
			var tNumB = packet.slice(16, 20);
			tNumB = deriveKey2(tkb2, tNumB, 4);

			blockSize = tNumB.readUInt32BE(0) + 20;

			dataSeg = packet.slice(16 + 4);
		}
		else
		{
			blockSize = 65536;
			dataSeg = packet.slice(16);
		}
		//var dataSeg = packet.slice(16);

		var dataBuffers = [];
		var i = 0;

		while (i < dataSeg.length)
		{
			var start = i;
			var end = Math.min(i + (blockSize), dataSeg.length);

			end -= 20;

			var eBuf = dataSeg.slice(start, end);
			var dBuf = deriveKey2(tkb2, eBuf, end - start);

			// remove packetkey to work with server, jsut testing and such
			//var messageDigest = getMessageDigest(eBuf, keyBitVer, packetKeyOld);
			var messageDigest = getMessageDigest(eBuf, keyBitVer);
			var hBufAgainst = dataSeg.slice(end, end + 20);

			if (!client && !sessionKey)
			{
				if (buffertools.compare(messageDigest, hBufAgainst) !== 0)
				{
					console.log(packet.toString());
					throw 'message digest of received buffers does not match';
				}
			}

			dataBuffers.push(dBuf);

			i += blockSize;
		}

		var dataDec = Buffer.concat(dataBuffers);

		return dataDec;
	}

	function encrypt(packet, sessionKey)
	{
		var cryptoKey = getBaseKey(false);

		if (sessionKey)
		{
			var newKey = new Buffer(16);

			for (var i = 0; i < 16; i++)
			{
				newKey.writeUInt8(cryptoKey.readUInt8(i) ^ sessionKey.readUInt8(i), i);
			}

			cryptoKey = newKey;
		}

		var dataBuffers = [];
		var outHeader = new Buffer(16);

		dataBuffers.push(outHeader);

		// 0x3C is our static xor 'key' pattern
		var packetKey = new Buffer(16);
		packetKey.fill(0x3C);

		for (var i = 0; i < 16; i++)
		{
			outHeader.writeUInt8(0x3C ^ (cryptoKey.readUInt8(i % 16)), i);
		}

		var verifKey = getBaseKey(true);

		// write and encrypt the block size
		var blockSize = 1024;

		var numBuffer = new Buffer(4);
		numBuffer.writeUInt32BE(blockSize, 0);

		var tkb1 = deriveKey1(packetKey, 16);
		//numBuffer = deriveKey2(tkb1, numBuffer, 4);

		//outHeader.writeUInt32BE(numBuffer.readUInt32BE(0), 16);

		// write the data segment
		var i = 0;

		while (i < packet.length)
		{
			var start = i;
			var end = Math.min(i + blockSize, packet.length);

			var dBuf = packet.slice(start, end);
			var eBuf = deriveKey2(tkb1, dBuf, end - start);

			dataBuffers.push(eBuf);

			var messageDigest = getMessageDigest(eBuf, verifKey, outHeader, (sessionKey) ? packetKey : null);

			dataBuffers.push(messageDigest);

			i += blockSize;
		}

		return Buffer.concat(dataBuffers);
	}

	function setSecret(secret)
	{
		g_secret = secret;
	}

	return {
		decrypt: decrypt,
		encrypt: encrypt,
		setSecret: setSecret,
		getBaseKey: getBaseKey,
	    encryptUA: encryptUserAgent
	};
};