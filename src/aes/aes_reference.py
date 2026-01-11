#!/usr/bin/env python3

from Crypto.Cipher import AES

def opentitan_to_aes_state(ot_state):
    plaintext = bytearray(16)
    for col in range(4):
        for row in range(4):
            plaintext[col * 4 + row] = ot_state[row][col]
    return bytes(plaintext)

def aes_state_to_opentitan(ciphertext_bytes):

    state = [[0 for _ in range(4)] for _ in range(4)]
    for col in range(4):
        for row in range(4):
            state[row][col] = ciphertext_bytes[col * 4 + row]
    return state

def opentitan_key_to_aes(ot_key):
    key_bytes = bytearray(16)
    for word_idx in range(4):  # Only first 4 words for AES-128
        word = ot_key[word_idx]
        # Extract bytes from 32-bit word in little-endian format
        key_bytes[word_idx * 4 + 0] = (word >> 0) & 0xFF   # LSB
        key_bytes[word_idx * 4 + 1] = (word >> 8) & 0xFF
        key_bytes[word_idx * 4 + 2] = (word >> 16) & 0xFF
        key_bytes[word_idx * 4 + 3] = (word >> 24) & 0xFF  # MSB
    return bytes(key_bytes)

def print_state_hex(state, title):

    print(f"{title}:")
    for row in range(4):
        row_str = ", ".join([f"{state[row][col]:02x}" for col in range(4)])
        print(f"[Row {row}] {row_str}")
    print()

def main():

    print("=== AES-128 Reference Implementation ===\n")
    

    plaintext_ot_fl = [
        [0x01, 0x02, 0x03, 0x04],  # Row 0
        [0x05, 0x06, 0x07, 0x08],  # Row 1
        [0x09, 0x0a, 0x0b, 0x0c],  # Row 2
        [0x0d, 0x0e, 0x0f, 0x10]   # Row 3
    ]
    plaintext_ot = plaintext_ot_fl[::-1]
    

    key_ot_f = [
        0x04030201,  # word 0: {0x04, 0x03, 0x02, 0x01}
        0x0c0b0a09,  # word 1: {0x0c, 0x0b, 0x0a, 0x09}
        0x14131211,  # word 2: {0x14, 0x13, 0x12, 0x11}
        0x1c1b1a19,  # word 3: {0x1c, 0x1b, 0x1a, 0x19}
        0x24232221,  # word 4 (not used in AES-128)
        0x2c2b2a29,  # word 5
        0x34333231,  # word 6
        0x3c3b3a39   # word 7
    ]

    key_ot = key_ot_f[::-1]  # Reverse the order for OpenTitan format

    print_state_hex(plaintext_ot, "Input Plaintext (OpenTitan format)")
    

    plaintext_bytes = opentitan_to_aes_state(plaintext_ot)
    key_bytes = opentitan_key_to_aes(key_ot)
    
    print("Plaintext bytes:", " ".join([f"{b:02x}" for b in plaintext_bytes]))
    print("Key bytes:      ", " ".join([f"{b:02x}" for b in key_bytes]))
    print()
    

    cipher = AES.new(key_bytes, AES.MODE_ECB)
    ciphertext_bytes = cipher.encrypt(plaintext_bytes)
    
    print("Ciphertext bytes:", " ".join([f"{b:02x}" for b in ciphertext_bytes]))
    print()
    

    ciphertext_ot = aes_state_to_opentitan(ciphertext_bytes)
    print_state_hex(ciphertext_ot, "Expected Ciphertext (OpenTitan format)")
    

    your_output = [
        [0x00, 0x8f, 0xc6, 0x44],
        [0x25, 0x52, 0x95, 0xc8],
        [0xa9, 0xea, 0x5c, 0x93],
        [0x0d, 0x55, 0x47, 0xbe]
    ]
    
    print_state_hex(your_output, "Your Current Output")
    

    print("=== Decryption Test ===")
    decrypted_bytes = cipher.decrypt(ciphertext_bytes)
    decrypted_ot = aes_state_to_opentitan(decrypted_bytes)
    print_state_hex(decrypted_ot, "Decrypted (should match original plaintext)")
    

    matches = True
    for row in range(4):
        for col in range(4):
            if plaintext_ot[row][col] != decrypted_ot[row][col]:
                matches = False
                break
    
    print(f"Decryption test: {'PASS' if matches else 'FAIL'}")

if __name__ == "__main__":
    main()
