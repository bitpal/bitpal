defmodule BitPal.Backend.FloweeFixtures do
  # Outgoing messages

  def get_blockchain_info do
    <<7, 0, 8, 1, 16, 0, 4>>
  end

  def block_subscribe do
    <<7, 0, 8, 18, 16, 0, 4>>
  end

  def ping do
    <<6, 0, 8, 126, 44, 4>>
  end

  # Incoming messages
  # All incoming messages must be prefixed by a <<low, high>> size tuple.

  def pong do
    [<<6, 0>>, <<8, 126, 52, 4>>]
  end

  def supscriber_reply do
    [
      <<9, 0>>,
      <<8, 17, 16, 1, 4, 168, 1>>
    ]
  end

  def version_msg do
    # Version: Flowee: 1 (2021-05) (note: this version might not actually exist).
    [
      <<27, 0>>,
      <<8, 0, 16, 1, 4, 10, 18, 70, 108, 111, 119, 101, 101, 58, 49, 32, 40, 50, 48, 50, 49, 45,
        48, 53, 41>>
    ]
  end

  def blockchain_info do
    # blocks: 690637,
    # chain: "main",
    # verification_progress: 0.9999991259829738
    # and other things
    [
      <<121, 0>>,
      <<8, 1, 16, 1, 4, 250, 67, 4, 109, 97, 105, 110, 248, 68, 169, 146, 77, 248, 69, 169, 146,
        77, 251, 70, 32, 174, 24, 235, 131, 167, 234, 90, 172, 94, 143, 153, 48, 60, 164, 140,
        219, 240, 22, 239, 83, 5, 65, 77, 2, 0, 0, 0, 0, 0, 0, 0, 0, 254, 64, 110, 183, 46, 254,
        113, 30, 85, 66, 248, 65, 133, 132, 226, 147, 43, 254, 71, 189, 3, 196, 42, 254, 255, 239,
        63, 251, 66, 32, 168, 2, 151, 75, 224, 43, 183, 138, 37, 250, 110, 1, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>
    ]
  end

  def new_block do
    # height: 690638
    [
      <<45, 0>>,
      <<8, 18, 16, 4, 4, 43, 32, 159, 32, 92, 122, 189, 152, 229, 154, 235, 96, 125, 114, 214,
        111, 152, 60, 113, 181, 108, 231, 140, 136, 138, 2, 0, 0, 0, 0, 0, 0, 0, 0, 56, 169, 146,
        78>>
    ]
  end

  def tx_seen do
    # bitcoincash:qzhw8q9n8dqetkzx5mg3xh43uqhumx5rl549dlrs72
    # amount: 1000
    # txid: 2f42c17858f7b080aa7d8b0b6b063c553a23d9151ed23b4ac9ed32cd2aef38a1
    [
      <<78, 0>>,
      <<8, 17, 16, 3, 4, 75, 32, 31, 130, 166, 200, 190, 225, 71, 52, 156, 43, 185, 148, 193, 163,
        224, 115, 49, 237, 124, 63, 100, 112, 219, 171, 149, 241, 84, 140, 30, 130, 77, 146, 48,
        134, 104, 35, 32, 161, 56, 239, 42, 205, 50, 237, 201, 74, 59, 210, 30, 21, 217, 35, 58,
        85, 60, 6, 107, 11, 139, 125, 170, 128, 176, 247, 88, 120, 193, 66, 47>>
    ]
  end

  def tx_1_conf do
    # bitcoincash:qzhw8q9n8dqetkzx5mg3xh43uqhumx5rl549dlrs72
    # amount: 1000,
    # height: 690638,
    # offset: 252615,
    # txid: 2f42c17858f7b080aa7d8b0b6b063c553a23d9151ed23b4ac9ed32cd2aef38a1
    [
      <<86, 0>>,
      <<8, 17, 16, 3, 4, 75, 32, 31, 130, 166, 200, 190, 225, 71, 52, 156, 43, 185, 148, 193, 163,
        224, 115, 49, 237, 124, 63, 100, 112, 219, 171, 149, 241, 84, 140, 30, 130, 77, 146, 48,
        134, 104, 35, 32, 161, 56, 239, 42, 205, 50, 237, 201, 74, 59, 210, 30, 21, 217, 35, 58,
        85, 60, 6, 107, 11, 139, 125, 170, 128, 176, 247, 88, 120, 193, 66, 47, 64, 142, 180, 71,
        56, 169, 146, 78>>
    ]
  end

  def multi_tx_seen do
    # bitcoincash:qrwjyrzae2av8wxvt79e2ukwl9q58m3u6cwn8k2dpa
    # bitcoincash:qz96wvrhsrg9j3rnczg7jkh3dlgshtcxzu89qrrcgc
    # amount: 10000
    # amount: 20000
    # txid: ...
    [
      <<116, 0>>,
      <<8, 17, 16, 3, 4, 75, 32, 155, 134, 125, 18, 44, 85, 192, 201, 165, 210, 104, 235, 218, 84,
        114, 130, 85, 57, 225, 101, 84, 87, 239, 252, 200, 122, 185, 53, 18, 128, 157, 185, 75,
        32, 74, 68, 61, 59, 35, 8, 83, 181, 175, 68, 97, 96, 214, 136, 211, 35, 0, 33, 218, 212,
        156, 151, 129, 121, 140, 251, 126, 6, 23, 125, 222, 45, 48, 205, 16, 48, 128, 155, 32, 35,
        32, 151, 246, 44, 146, 171, 137, 223, 61, 249, 224, 102, 157, 33, 202, 220, 24, 30, 6, 71,
        207, 196, 89, 198, 242, 80, 44, 218, 220, 164, 193, 209, 86>>
    ]
  end

  def multi_tx_a_seen do
    # bitcoincash:qrwjyrzae2av8wxvt79e2ukwl9q58m3u6cwn8k2dpa
    # amount: 5000
    # txid: ...
    [
      <<78, 0>>,
      <<8, 17, 16, 3, 4, 75, 32, 155, 134, 125, 18, 44, 85, 192, 201, 165, 210, 104, 235, 218, 84,
        114, 130, 85, 57, 225, 101, 84, 87, 239, 252, 200, 122, 185, 53, 18, 128, 157, 185, 48,
        166, 8, 35, 32, 53, 201, 123, 197, 8, 47, 238, 62, 224, 89, 113, 112, 73, 90, 18, 118,
        239, 70, 3, 29, 3, 53, 1, 31, 57, 104, 247, 187, 216, 117, 128, 140>>
    ]
  end

  def multi_tx_1_conf do
    # bitcoincash:qrwjyrzae2av8wxvt79e2ukwl9q58m3u6cwn8k2dpa
    # bitcoincash:qz96wvrhsrg9j3rnczg7jkh3dlgshtcxzu89qrrcgc
    # amount: 10000
    # amount: 20000
    # height: 690933
    # txid: ...
    [
      <<124, 0>>,
      <<8, 17, 16, 3, 4, 75, 32, 155, 134, 125, 18, 44, 85, 192, 201, 165, 210, 104, 235, 218, 84,
        114, 130, 85, 57, 225, 101, 84, 87, 239, 252, 200, 122, 185, 53, 18, 128, 157, 185, 75,
        32, 74, 68, 61, 59, 35, 8, 83, 181, 175, 68, 97, 96, 214, 136, 211, 35, 0, 33, 218, 212,
        156, 151, 129, 121, 140, 251, 126, 6, 23, 125, 222, 45, 48, 205, 16, 48, 128, 155, 32, 35,
        32, 151, 246, 44, 146, 171, 137, 223, 61, 249, 224, 102, 157, 33, 202, 220, 24, 30, 6, 71,
        207, 196, 89, 198, 242, 80, 44, 218, 220, 164, 193, 209, 86, 64, 133, 230, 98, 56, 169,
        148, 117>>
    ]
  end

  def multi_tx_a_1_conf do
    # bitcoincash:qrwjyrzae2av8wxvt79e2ukwl9q58m3u6cwn8k2dpa
    # amount: 5000
    # height: 690934
    # txid: ...
    [
      <<86, 0>>,
      <<8, 17, 16, 3, 4, 75, 32, 155, 134, 125, 18, 44, 85, 192, 201, 165, 210, 104, 235, 218, 84,
        114, 130, 85, 57, 225, 101, 84, 87, 239, 252, 200, 122, 185, 53, 18, 128, 157, 185, 48,
        166, 8, 35, 32, 53, 201, 123, 197, 8, 47, 238, 62, 224, 89, 113, 112, 73, 90, 18, 118,
        239, 70, 3, 29, 3, 53, 1, 31, 57, 104, 247, 187, 216, 117, 128, 140, 64, 135, 253, 126,
        56, 169, 148, 118>>
    ]
  end
end
