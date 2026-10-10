(* ================================================================= *)
(* TRACKING_CALC_CONT - THUẬT TOÁN TRACKING LIÊN TỤC (KHÔNG QD75)    *)
(* Chỉ tính toán vị trí bám vật trôi băng tải. Điều khiển QD75/Y10/  *)
(*  van keo nằm file khác, đọc rTarg/iSeg/bHasTarg qua biến chung.   *)
(* Đơn vị: mm; mm/s; D4010 đơn vị 0.1 độ -> đổi sang radian;          *)
(*  dt = 0.01 s (scan 10ms); 0.1um = mm * 10000.0.                   *)
(* Đầu vào: M500 (mức cho phép), M1000 (xung nạp phôi), bPtDone      *)
(*  (xung 1 scan từ phía chuyển động báo ĐÃ TỚI ĐIỂM).               *)
(* Đọc thẳng D: D1000/D2000 (X/Y tâm lúc chụp, mm), D4000 (tốc độ    *)
(*  băng live, mm/s), D4010 (góc xoay, 0.1 độ).                      *)
(* Ra cho phần sau + motion: rTarg (REAL mm), dTarg (DINT 0.1um ra    *)
(*  D1010/D2010/D3010), dStart (điểm đầu đoạn ra D1020/D2020/D3020),  *)
(*  dSpdStg (tốc độ ra D4020), wMotionType = 1 (ra D4030).            *)
(* ================================================================= *)

(* ---- PHẦN A: INIT + M500 + THƯỚC DÂY E + FIFO 16 + XUNG ĐIỂM ---- *)

(* 1. INIT - chạy 1 lần sau RUN (SM402 ON đúng 1 scan đầu). Gán sạch *)
(*  toàn bộ biến trạng thái để không rác gây lỗi 4100. *)
IF SM402 OR NOT bInit THEN
    bInit := TRUE; (* cờ đã init, chống chạy lại mỗi scan *)
    bPrevTrig := FALSE; (* nhớ M1000 scan trước để bắt cạnh lên *)
    bPrevEn := FALSE; (* nhớ M500 scan trước để bắt cạnh lên *)
    bPrevDone := FALSE; (* nhớ bPtDone scan trước để bắt cạnh lên *)
    bPtPulse := FALSE; (* xung 1 scan báo tới điểm, mặc định tắt *)
    rEncDist := 0.0; (* thước dây E: quãng đường băng đã chạy, mm *)
    rBelt := 0.0; (* tốc độ băng thô vừa đọc, mm/s *)
    rBeltF := 0.0; (* tốc độ sau lọc trượt, mm/s *)
    rAlpha := 1.0; (* hệ số lọc = 1.0 là lấy thẳng, chưa lọc *)
    rDt := 0.01; (* chu kỳ scan 10ms = 0.01 s *)
    rLeadT := 0.8; (* thời gian đón đầu 0.8 s để bù độ trễ cơ khí *)
    iHead := 0; (* con trỏ đầu hàng FIFO (chỗ pop) *)
    iTail := 0; (* con trỏ đuôi hàng FIFO (chỗ push) *)
    iCnt := 0; (* số phôi đang chờ trong hàng *)
    bActive := FALSE; (* FALSE = robot rảnh, TRUE = đang làm 1 phôi *)
    bQFull := FALSE; (* FALSE = hàng chưa đầy *)
    iState := 0; (* 0 = chờ, 10 = có phôi để tính *)
    iCorner := 1; (* góc 1..4 đang tính *)
    rPartX0 := 0.0; (* X tâm phôi lúc chụp, mm *)
    rPartY0 := 0.0; (* Y tâm phôi lúc chụp, mm *)
    rPartAng := 0.0; (* góc xoay rad lúc chụp *)
    rPartE0 := 0.0; (* mốc E lúc chụp, mm *)
END_IF;
(* 1b. Cạnh lên M500: reset sạch như mới RUN (đổi mẻ / bắt đầu mẻ mới). *)
(*  M500 OFF: dừng tracking, robot về chờ, không tính nữa. *)
IF M500 AND NOT bPrevEn THEN
    rEncDist := 0.0; (* xóa thước dây *)
    rBelt := 0.0;
    rBeltF := 0.0;
    iHead := 0; (* xóa hàng đợi *)
    iTail := 0;
    iCnt := 0;
    bActive := FALSE; (* thả phôi đang làm *)
    bQFull := FALSE;
    iState := 0;
    iCorner := 1;
    rPartX0 := 0.0;
    rPartY0 := 0.0;
    rPartAng := 0.0;
    rPartE0 := 0.0;
    bPrevTrig := FALSE;
    bPrevDone := FALSE;
    bPtPulse := FALSE;
END_IF;
bPrevEn := M500; (* cập nhật nhớ M500 mỗi scan *)
IF NOT M500 THEN (* M500 OFF: dừng khẩn, giữ nguyên Y0 bên ngoài *)
    bActive := FALSE;
    iState := 0;
    bPtPulse := FALSE;
    bPrevDone := bPtDone;
    bPrevTrig := M1000;
END_IF;
(* 2. THƯỚC DÂY E - cộng dồn mỗi scan khi M500 ON. Đây là chỗ       *)
(*  "tính liên tục": băng đổi tốc là E cộng theo ngay, không chờ   *)
(*  hết điểm. v đọc live D4000 mỗi scan. *)
IF M500 THEN
    rBelt := INT_TO_REAL(D4000); (* D4000 INT mm/s -> REAL *)
    rBeltF := rBeltF + ((rBelt - rBeltF) * rAlpha); (* lọc trượt *)
    rEncDist := rEncDist + (rBelt * rDt); (* E += v * dt *)
END_IF;
(* 3-6. FIFO 16 + nhận bPtDone - chỉ chạy khi M500 ON. *)
IF M500 THEN
    (* 3. Cạnh lên M1000: chốt 1 phôi vào đuôi hàng. Cấm giữ M1000 *)
    (*  ON liên tục (mỗi scan push 1 phôi giả làm đầy hàng). *)
    IF M1000 AND NOT bPrevTrig THEN
        IF iCnt < 16 THEN
            qPX[iTail] := INT_TO_REAL(D1000); (* X tâm lúc chụp *)
            qPY[iTail] := INT_TO_REAL(D2000); (* Y tâm lúc chụp *)
            qPAng[iTail] := (INT_TO_REAL(D4010) / 10.0) * 0.0174532925; (* 0.1 độ -> rad *)
            qPE[iTail] := rEncDist; (* mốc E lúc chụp để trừ trượt *)
            iTail := (iTail + 1) MOD 16; (* quay vòng 0..15 *)
            iCnt := iCnt + 1;
        ELSE
            bQFull := TRUE; (* đầy 16: báo ra M3000, bỏ mẫu mới *)
        END_IF;
    END_IF;
    bPrevTrig := M1000; (* nhớ để bắt cạnh scan sau *)
    (* 4. Robot rảnh + còn phôi chờ: pop đầu hàng ra làm. *)
    IF (NOT bActive) AND (iCnt > 0) THEN
        rPartX0 := qPX[iHead];
        rPartY0 := qPY[iHead];
        rPartAng := qPAng[iHead];
        rPartE0 := qPE[iHead];
        iHead := (iHead + 1) MOD 16;
        iCnt := iCnt - 1;
        bActive := TRUE; (* bắt đầu 1 phôi mới *)
        iCorner := 1; (* luôn từ góc 1 *)
        iState := 10; (* báo có phôi cho phần sau *)
    END_IF;
    IF iCnt < 16 THEN
        bQFull := FALSE; (* xả bớt là hết đầy *)
    END_IF;
    (* 5. Nhận bPtDone: chỉ lấy CẠNH LÊN, ra bPtPulse đúng 1 scan. *)
    (*  Phía chuyển động bắn xung khi TỚI ĐIỂM; giữ ON cũng chỉ +1. *)
    IF bPtDone AND NOT bPrevDone THEN
        bPtPulse := TRUE;
    ELSE
        bPtPulse := FALSE;
    END_IF;
    bPrevDone := bPtDone;
    (* 6. Rỗi (không làm, hàng rỗng): E = 0 chống tràn số thực. *)
    IF (NOT bActive) AND (iCnt = 0) THEN
        rEncDist := 0.0;
        rBeltF := 0.0;
    END_IF;
END_IF;

(* ---- PHẦN B: XOAY GÓC + MỤC TIÊU + RA DINT ---- *)
(* Đọc Phần A (không khai lại): rPartX0/rPartY0/rPartAng/rPartE0,   *)
(*  rEncDist/rBeltF/rLeadT/bActive/bPtPulse. Đọc thẳng: D3000/      *)
(*  D3001/D4002/D4004 + M500. Tự quản lý: iSeg 1..12, iCorner theo *)
(*  cụm seg (1..3->góc1, 4..6->góc2, 7..9->góc3, 10..12->góc4),      *)
(*  iPhase theo seg (((iSeg - 1) MOD 3) + 1): 1 bay / 2 hạ / 3 nhấc,*)
(*  bSegInit xung 1 scan khi đổi seg để chốt điểm đầu rLast.        *)
(*  Ra: rTargX/Y/Z + dTarg/dStart/dSpdStg + wMotionType = 1.        *)
(*  Không DTO/TO/FROM/Y10/X4/van/DMOV/VAR.                         *)
IF SM402 THEN (* init riêng phần B *)
    iSeg := 0; (* đoạn 0 = chưa có đoạn nào *)
    iCorner := 1;
    iPhase := 1; (* 1 bay / 2 hạ-phun / 3 nhấc *)
    bHasTarg := FALSE; (* chưa có target cho motion *)
    bSegInit := FALSE; (* xung chốt rLast *)
    bPrevActive := FALSE; (* nhớ cạnh bActive để bắt đoạn 1 *)
    rLastX := 0.0; (* điểm đầu đoạn X, mm *)
    rLastY := 0.0;
    rLastZ := 0.0;
END_IF;
IF NOT M500 THEN (* M500 OFF: đưa về chờ *)
    iSeg := 0;
    iCorner := 1;
    iPhase := 1;
    bHasTarg := FALSE;
    bSegInit := FALSE;
    bPrevActive := FALSE;
ELSE
    bSegInit := FALSE; (* mặc định tắt, chỉ bật 1 scan khi đổi đoạn *)
    IF bActive AND NOT bPrevActive THEN (* phôi mới vừa pop: mở đoạn 1 *)
        iSeg := 1;
        iCorner := 1;
        iPhase := 1;
        bHasTarg := TRUE;
        bSegInit := TRUE; (* chốt rLast = target đoạn 1 *)
    ELSIF bActive AND bPtPulse THEN (* tới điểm: sang đoạn tiếp theo *)
        IF (iSeg >= 1) AND (iSeg < 12) THEN
            iSeg := iSeg + 1;
            IF iSeg <= 3 THEN
                iCorner := 1; (* đoạn 1..3 thuộc góc 1 *)
            ELSIF iSeg <= 6 THEN
                iCorner := 2; (* đoạn 4..6 thuộc góc 2 *)
            ELSIF iSeg <= 9 THEN
                iCorner := 3; (* đoạn 7..9 thuộc góc 3 *)
            ELSE
                iCorner := 4; (* đoạn 10..12 thuộc góc 4 *)
            END_IF;
            iPhase := ((iSeg - 1) MOD 3) + 1; (* 1 bay, 2 hạ, 3 nhấc *)
            bHasTarg := TRUE;
            bSegInit := TRUE; (* chốt rLast đầu đoạn mới *)
        ELSIF iSeg = 12 THEN (* xong đoạn 12: thả phôi, chờ pop tiếp *)
            bActive := FALSE;
            bHasTarg := FALSE;
            iSeg := 0;
            iCorner := 1;
            iPhase := 1;
            bSegInit := FALSE;
        END_IF;
    ELSIF NOT bActive THEN (* rỗi: tắt target *)
        bHasTarg := FALSE;
        iSeg := 0;
        iCorner := 1;
        iPhase := 1;
    END_IF;
    bPrevActive := bActive;
END_IF;
IF D3000 > 0 THEN (* D3000 INT 0.1mm -> Z bay mm *)
    rZbay := INT_TO_REAL(D3000) / 10.0;
ELSE
    rZbay := 10.0; (* quên nhập lấy 10mm *)
END_IF;
IF D3001 > 0 THEN (* D3001 INT 0.1mm -> Z chấm keo mm *)
    rZcham := INT_TO_REAL(D3001) / 10.0;
ELSE
    rZcham := 40.0; (* quên nhập lấy 40mm *)
END_IF;
IF rZbay < 0.0 THEN (* kẹp biên cơ khí Z 0..50 *)
    rZbay := 0.0;
END_IF;
IF rZbay > 50.0 THEN
    rZbay := 50.0;
END_IF;
IF rZcham < 0.0 THEN
    rZcham := 0.0;
END_IF;
IF rZcham > 50.0 THEN
    rZcham := 50.0;
END_IF;
rMaster := INT_TO_REAL(D4002); (* tốc độ master mm/phút *)
IF rMaster <= 0.0 THEN
    rMaster := 10000.0; (* quên nhập lấy 10000 *)
END_IF;
rSpdMax := INT_TO_REAL(D4004); (* trần = Pr.8 mm/phút *)
IF rSpdMax <= 0.0 THEN
    rSpdMax := 20000.0;
END_IF;
IF rLeadT <= 0.0 THEN
    rLeadT := 0.8; (* đón đầu mặc định 0.8 s *)
END_IF;
IF bHasTarg THEN (* có target mới tính, rỗi thì giữ số cũ *)
    CASE iCorner OF (* chọn góc vuông chưa xoay, nửa cạnh 20mm *)
        1:
            rDx0 := 0.0 - 20.0; (* góc1 (-20,-20) *)
            rDy0 := 0.0 - 20.0;
        2:
            rDx0 := 20.0; (* góc2 (+20,-20) *)
            rDy0 := 0.0 - 20.0;
        3:
            rDx0 := 20.0; (* góc3 (+20,+20) *)
            rDy0 := 20.0;
        4:
            rDx0 := 0.0 - 20.0; (* góc4 (-20,+20) *)
            rDy0 := 20.0;
        ELSE
            rDx0 := 0.0 - 20.0;
            rDy0 := 0.0 - 20.0;
    END_CASE;
    COS_E(TRUE, rPartAng, rCosVal); (* cos góc, 3 tham số EN/góc/ra *)
    SIN_E(TRUE, rPartAng, rSinVal); (* sin góc *)
    rDxRot := (rDx0 * rCosVal) - (rDy0 * rSinVal); (* ma trận xoay X *)
    rDyRot := (rDx0 * rSinVal) + (rDy0 * rCosVal); (* ma trận xoay Y *)
    (* CÔNG THỨC CHÍNH: tâm lúc chụp + quãng băng đã trôi + đón đầu *)
    (*  tốc độ + lệch góc xoay. E tính liên tục nên target bám theo. *)
    rTargX := rPartX0 + (rEncDist - rPartE0) + (rBeltF * rLeadT) + rDxRot;
    rTargY := rPartY0 + rDyRot; (* băng chỉ chạy X nên Y không lead *)
    CASE iPhase OF (* Z + tốc độ theo pha *)
        1:
            rTargZ := rZbay; (* bay trên đỉnh *)
            rSpd := rMaster * 0.6;
        2:
            rTargZ := rZcham; (* hạ xuống chấm keo *)
            rSpd := rMaster * 0.12;
        3:
            rTargZ := rZbay; (* nhấc lên *)
            rSpd := rMaster * 0.3;
        ELSE
            rTargZ := rZbay;
            rSpd := rMaster * 0.6;
    END_CASE;
    IF rSpd > rSpdMax THEN
        rSpd := rSpdMax; (* kẹp trần Pr.8 *)
    END_IF;
    IF rTargX < 0.0 THEN (* kẹp biên X 0..170 *)
        rTargX := 0.0;
    END_IF;
    IF rTargX > 170.0 THEN
        rTargX := 170.0;
    END_IF;
    IF rTargY < 0.0 THEN (* kẹp biên Y 0..170 *)
        rTargY := 0.0;
    END_IF;
    IF rTargY > 170.0 THEN
        rTargY := 170.0;
    END_IF;
    IF rTargZ < 0.0 THEN (* kẹp biên Z 0..50 *)
        rTargZ := 0.0;
    END_IF;
    IF rTargZ > 50.0 THEN
        rTargZ := 50.0;
    END_IF;
    IF bSegInit THEN (* đầu đoạn mới: chốt điểm đầu cho VC *)
        rLastX := rTargX;
        rLastY := rTargY;
        rLastZ := rTargZ;
    END_IF;
    dTargX_01um := REAL_TO_DINT(rTargX * 10000.0); (* mm -> 0.1um ra D1010 *)
    dTargY_01um := REAL_TO_DINT(rTargY * 10000.0); (* ra D2010 *)
    dTargZ_01um := REAL_TO_DINT(rTargZ * 10000.0); (* ra D3010 *)
    dStartX_01um := REAL_TO_DINT(rLastX * 10000.0); (* điểm đầu ra D1020 *)
    dStartY_01um := REAL_TO_DINT(rLastY * 10000.0); (* ra D2020 *)
    dStartZ_01um := REAL_TO_DINT(rLastZ * 10000.0); (* ra D3020 *)
    dSpdStg := REAL_TO_DINT(rSpd); (* tốc độ ra D4020 *)
END_IF;
wMotionType := 1; (* 1 = đường thẳng, ra D4030 *)
(* RA D CHO MOTION/VC - 32-bit DMOV vao cap D, 16-bit MOV *)
(* D1010=D1010+D1011, word cao cam dung rieng *)
DMOV(TRUE, dTargX_01um, D1010); (* X cuoi 0.1um *)
DMOV(TRUE, dTargY_01um, D2010); (* Y cuoi 0.1um *)
DMOV(TRUE, dTargZ_01um, D3010); (* Z cuoi 0.1um *)
DMOV(TRUE, dStartX_01um, D1020); (* X dau doan *)
DMOV(TRUE, dStartY_01um, D2020); (* Y dau doan *)
DMOV(TRUE, dStartZ_01um, D3020); (* Z dau doan *)
DMOV(TRUE, dSpdStg, D4020); (* toc do *)
MOV(TRUE, wMotionType, D4030); (* 1 = duong thang *)
MOV(TRUE, iSeg, D4031); (* doan 1..12 dang chay *)
MOV(TRUE, iCorner, D4032); (* goc 1..4 *)
