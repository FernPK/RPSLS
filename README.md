# RPSLS
smart contract ที่ผู้ใช้งานสามารถเล่นเกมส์ที่มีกฏเกณฑ์การแพ้ ชนะ และเสมอ ตายตัว และจะมีการจ่ายเงิน ETH ไปให้กับผู้ที่ชนะ หรือแบ่งเงินในกรณีเสมอ

<img src="https://github.com/user-attachments/assets/93ff8372-5e89-40b3-b409-8ab889494c03" alt="game rules" width="300"/>

## วิธีการเล่น

1. ผู้ที่ต้องการเล่นเรียก function `addPlayer` พร้อมเงินเดิมพัน 1 ETH ใน 1 รอบต้องการผู้เล่น 2 คน กรณีมีผู้เล่นไม่ครบภายใน 20 นาที ผู้เล่นที่วางเดิมพันไว้สามารถถอนเงินของตนเองได้ด้วยการเรียก function `getRefund`
2. เมื่อมีผู้เล่นครบ 2 คน ผู้เล่นจะต้องเลือก choice ที่จะเป็นตัวตัดสินผลแพ้ชนะ แล้วเตรียมตัว commit hash ด้วยวิธีนี้**เท่านั้น**

    1) เตรียม string ที่ประกอบด้วย random string และ choice ดังนี้
    ```
    import random
    # generate 31 random bytes
    rand_num = random.getrandbits(256 - 8)
    rand_bytes = hex(rand_num)
    
    # choice: '00', '01', '02', '03', '04' (Scissors, Paper, Rock, Lizard, Spock)
    # concatenate choice to rand_bytes to make 32 bytes data_input
    choice = '01'
    data_input = rand_bytes + choice
    print(data_input)
    print(len(data_input))
    print()
    
    # need padding if data_input has less than 66 symbols (< 32 bytes)
    if len(data_input) < 66:
      print("Need padding.")
      data_input = data_input[0:2] + '0' * (66 - len(data_input)) + data_input[2:]
      assert(len(data_input) == 66)
    else:
      print("Need no padding.")
    print("Choice is", choice)
    print("Use the following bytes32 as an input to the getHash function:", data_input)
    print(len(data_input))
    ```
    **กรุณาจำ string นี้ไว้เพื่อ reveal choice แล้วตัดสินผล หากผู้เล่นไม่สามารถ reveal choice ได้อย่างถูกต้อง สิทธิ์การได้เงินเดิมพันจะตกเป็นของอีกฝั่งทันที**

    2) นำ string ที่ได้จากข้อ 1 ไปเข้า function `getHash` ใน CommitReveal 

    กรณีมีผู้เล่นคนหนึ่งไม่เลือก choice หลังจากมีผู้เล่นคนแรกภายใน 20 นาที การเดิมพันจะถือเป็นโมฆะ ผู้เล่นสามารถเรียก function `getRefund` เพื่อถอนเงินส่วนของตนเองได้

3. เมื่อผู้เล่นทั้งสองคนเลือก choice แล้ว ผู้เล่นจะต้อง reveal choice อย่างถูกต้องทั้ง 2 คน แล้วจะมีการตัดสินผลแพ้-ชนะ-เสมอ
    - การ reveal ทำได้โดยเรียก function `revealChoice` พร้อมกับส่ง string ที่บอกให้จำไว้เป็น input
    - หากมีผู้เล่นไม่เปิดเผยหรือไม่สามารถเปิดเผย choice ได้ภายใน 20 นาที หลังจากมีผู้เล่นคนแรก สิทธิ์การได้รางวัลจะตกเป็นของอีกฝั่งทันที หากผู้เล่นอีกฝั่งสามารถ reveal ได้อย่างถูกต้อง ก็สามารถเรียก function `getRefund` เพื่อรับเงินเดิมพันทั้งหมดไปได้เลย
    - กรณีผลเสมอ เงินเดิมพันจะถูกแบ่งครึ่งแล้วโอนไปยังบัญชีของผู้เล่นแต่ละคนทันที 
    - กรณีมีผู้ชนะ เงินเดิมพันทั้งหมดจะถูกโอนไปยังบัญชีผู้ชนะ

## การแก้ไขปัญหา

### ปัญหา front-running
- ใช้กระบวนการ commit-reveal โดยเมื่อผู้เล่นเลือก choice แล้วจะต้องทำการสร้าง string ตามวิธีที่อธิบายไปแล้วด้านบน หลังจากนั้นนำ string ไปเข้า function `getHash` ใน CommitReveal แล้วใส่ digest ที่ได้ลงใน function `input`
  ```
  function input(bytes32 dataHash) public  {
      require(numPlayer == 2, "Need 2 players");
      require(player_not_played[msg.sender], "You have chosen the choice");
      // commit hash
      commitReveal.commit(dataHash, msg.sender);
      player_not_played[msg.sender] = false;
      numInput++;
  }
  ```
  โดยมีการเปลี่ยนแปลง function `commit` และ `reveal` ใน CommitReveal เพื่อรับ parameter ที่เป็น account address ของผู้ที่ต้องการ commit ด้วย เนื่องจากโจทย์บังคับให้ใช้การ import ที่ไม่ใช่แบบ inheritance หากเรียกใช้ function `commit` และ `reveal` ผ่าน function ของ contract เกม address ที่ทำการ commit จะกลายเป็น address ของ contract เกมแทน
- สำหรับการ reveal และตัดสินผล ผู้เล่นทั้ง 2 คนจะต้อง reveal ได้อย่างถูกต้อง โดยเรียก function `revealChoice` พร้อมใส่ input ที่เป็น string ก่อน hash ที่บอกให้จำไว้ดังคำอธิบายด้านบน กรณีที่ผู้เล่นทั้ง 2 คนสามารถ reveal ได้ถูกต้อง จะทำการดึงตัวเลขหลักสุดท้ายใน string ที่ใช้ reveal มาตัดสินผลแพ้ชนะ เนื่องจากตามวิธีการเตรียม string ที่กำหนดไว้ choice จะอยู่ท้ายสุดเสมอ จากนั้นก็ตัดสินผลตามกติกาของเกม
  ```
  function revealChoice (bytes32 revealHash) public {
      require(numInput == 2, "Need input from 2 players before reveal");
      require(!player_revealed[msg.sender], "You have already revealed");
      player_revealed[msg.sender] = true;
      // reveal hash
      commitReveal.reveal(revealHash, msg.sender);
      uint8 choiceFromHash = getChoiceFromHash(revealHash);
      player_choice[msg.sender] = choiceFromHash;
      numReveal++;
      if (numReveal == 2) {
          _checkWinnerAndPay();
      }
  }
  
  function getChoiceFromHash(bytes32 revealHash) public pure returns (uint8) {
      // Get the last byte and mod by 5
      uint8 choice = uint8(revealHash[revealHash.length - 1]) % 5;
      return choice;
  }
  ```
  แต่กรณีที่มีผู้เล่นที่ไม่สามารถ reveal ได้ภายในเวลาที่กำหนด ก็สามารถถอนเงินออกได้ตามกฎ สามารถดูได้ในส่วนถัดไป

### ปัญหาการ lock เงินไว้ใน contract และการจัดการกรณีผู้เล่นไม่ครบ
- เพิ่มการเก็บ timestamp เมื่อมีผู้เล่นคนแรก และกำหนดให้เกมมีระยะเวลา 20 นาที หากเกินระยะเวลานี้ เงินจะสามารถถอนออกไปได้แน่นอน แต่ก็ขึ้นอยู่กับกฎกติกาที่ได้อธิบายไปแล้วด้านบน
  - ที่ function `addPlayer` มีการ `setStartTime` เมื่อมีผู้เล่นคนแรก เพื่อบันทึก timestamp ที่ถือเป็นเวลาเริ่มต้นเกม
  ```
  function addPlayer() public payable {
      require(_isCallerAvailable(), "You are not available player");
      require(numPlayer < 2, "Already have 2 players");
      if (numPlayer > 0) {
          require(msg.sender != players[0], "You are already the first player");
      }
      require(msg.value == 1 ether, "Need to send 1 ether");
      reward += msg.value;
      player_not_played[msg.sender] = true;
      player_revealed[msg.sender] = false;
      players.push(msg.sender);
      numPlayer++;
      if (numPlayer == 1) {
          timeUnit.setStartTime();
      }
  }
  ```
  - ที่ function `getRefund` มีการตรวจสอบว่าเกมมีระยะเวลาเกิน `gameDuration` ซึ่งกำหนดให้เป็น 20 นาทีหรือไม่ ถ้าเกินก็จะสามารถถอนเงินออกไปได้ตามกฎกติกา
  ```
  function getRefund() public {
      require(_isCallerAvailable(), "You are not available player");
      require(numPlayer > 0, "The game has not started");
      uint elapsed = timeUnit.elapsedSeconds();
      require(elapsed >= gameDuration, "Not enough time passed to get refund");
      if (numPlayer == 1 && elapsed >= gameDuration) {
          // no player 2 in game duration
          address payable account0 = payable(players[0]);
          account0.transfer(reward);
          _reset();
      }
      else if (numPlayer == 2 && numInput < 2 && elapsed >= gameDuration) {
          // any player does not input choice in game duration
          address payable account0 = payable(players[0]);
          address payable account1 = payable(players[1]);
          account0.transfer(reward/2);
          account1.transfer(reward/2);
          _reset();
      }
      else if (numPlayer == 2 && numInput == 2 && numReveal < 2 && elapsed >= gameDuration) {
          // player does not reveal choice in game duration
          address payable account0 = payable(players[0]);
          address payable account1 = payable(players[1]);
          if (numReveal == 0) {
              account0.transfer(reward/2);
              account1.transfer(reward/2);
              _reset();
          }
          else if (player_revealed[players[0]]) {
              account0.transfer(reward);
              _reset();
          }
          else if (player_revealed[players[1]]) {
              account1.transfer(reward);
              _reset();
          }
      }
  }
  ```

### ปัญหาเล่นซ้ำไม่ได้
- สร้าง function `_reset` เพื่อ reset ตัวแปรที่ใช้เก็บ state ของ contract โดย function จะถูกเรียกหลังจาก

    1) การจ่ายเงินให้ผู้ชนะ
    2) การถอนเงิน ETH (getRefund) กรณีเล่นไม่จบเกม
