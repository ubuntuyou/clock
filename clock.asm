;;;;;;;;;;;;;;;;;;;;;;;
;;;   iNES HEADER   ;;;
;;;;;;;;;;;;;;;;;;;;;;;

    .db  "NES", $1a     ;identification of the iNES header
    .db  PRG_COUNT      ;number of 16KB PRG-ROM pages
    .db  $01            ;number of 8KB CHR-ROM pages
    .db  $70|MIRRORING  ;mapper 7
    .dsb $09, $00       ;clear the remaining bytes

    .fillvalue $FF      ; Sets all unused space in rom to value $FF

;;;;;;;;;;;;;;;;;;;;;
;;;   VARIABLES   ;;;
;;;;;;;;;;;;;;;;;;;;;

    .enum $0000 ; Zero Page variables

screenPtr       .dsb 2
metaTile        .dsb 1
counter         .dsb 1
rowCounter      .dsb 1
softPPU_Control .dsb 1
softPPU_Mask    .dsb 1

hours           .dsb 1
minutes         .dsb 1
seconds         .dsb 1
tick            .dsb 1

buttons         .dsb 1
oldButtons      .dsb 1

    .ende

    .enum $0400 ; Variables at $0400. Can start on any RAM page

sleeping        .dsb 1

    .ende
;;;;;;;;;;;;;;;;;;;;;
;;;   CONSTANTS   ;;;
;;;;;;;;;;;;;;;;;;;;;

PRG_COUNT       = 1       ;1 = 16KB, 2 = 32KB
MIRRORING       = %0001

PPU_Control     .equ $2000
PPU_Mask        .equ $2001
PPU_Status      .equ $2002
PPU_Scroll      .equ $2005
PPU_Address     .equ $2006
PPU_Data        .equ $2007

spriteRAM       .equ $0200

CONTROLLER_1    .equ $4016

    .org $C000
;;;;;;;;;;;;;;;;;
;;;   RESET   ;;;
;;;;;;;;;;;;;;;;;

RESET:
    sei
    cld
    lda #$40
    sta $4017
    ldx #$FF
    txs
    inx
    stx PPU_Control
    stx PPU_Mask
    stx $4010
    
vblank1:
    bit PPU_Status
    bpl vblank1

clrmem:
    lda #$00
    sta $0000,x
    sta $0100,x
    sta $0300,x
    sta $0400,x
    sta $0500,x
    sta $0600,x
    sta $0700,x
    lda #$FE
    sta $0200,x
    inx
    bne clrmem

vblank2:
    bit PPU_Status
    bpl vblank2
    
    lda #<background
    sta screenPtr
    lda #>background
    sta screenPtr+1

    lda PPU_Status
    lda #$20
    sta PPU_Address
    lda #$00
    sta PPU_Address

metaBackground:
    lda #$00
    sta metaTile
    eor #$0F
    sta rowCounter
@top:
    lda #$10
    sta counter

    ldy metaTile
@loop:
    lda (screenPtr),y
    tax
    lda topLeft,x
    sta PPU_Data
    lda topRight,x
    sta PPU_Data
    iny
    dec counter
    bne @loop

    tya
    sec
    sbc #$10
    tay

    lda #$10
    sta counter
@loop2:
    lda (screenPtr),y
    tax
    lda bottomLeft,x
    sta PPU_Data
    lda bottomRight,x
    sta PPU_Data
    iny
    dec counter
    bne @loop2
    
    sty metaTile

    dec rowCounter
    bne @top

loadAttributes:
    ldx #$00
@loop:
    lda attributes,x
    sta PPU_Data
    inx
    cpx #$40
    bne @loop

    lda #<palette
    sta screenPtr
    lda #>palette
    sta screenPtr+1

loadPalettes:
    lda PPU_Status
    lda #$3F
    sta PPU_Address
    lda #$00
    sta PPU_Address

    ldy #$00
@loop:
    lda (screenPtr),y
    sta PPU_Data
    iny
    cpy #$20
    bne @loop
    
loadSprite:
    ldx #$00
    ldy #$00
@loop
    lda sprite_Y,x
    sta spriteRAM,y
    iny
    lda sprite_Tile,x
    sta spriteRAM,y
    iny
    lda sprite_Attrib,x
    sta spriteRAM,y
    iny
    lda sprite_X,x
    sta spriteRAM,y
    iny
    inx
    cpx #$10
    bne @loop


    lda #%10010000
    sta PPU_Control
    sta softPPU_Control
    lda #%00011110
    sta PPU_Mask
    sta softPPU_Mask

    lda #$3C
    sta tick
    lda #$00
    sta seconds
    sta minutes
    lda #$0C
    sta hours
    
    lda #$80
    sta timeRAM+0
    sta timeRAM+4
    sta timeRAM+8
    sta timeRAM+12
    sta timeRAM+16
    sta timeRAM+20

    lda #$00
    sta timeRAM+2
    sta timeRAM+6
    sta timeRAM+10
    sta timeRAM+14
    sta timeRAM+18
    sta timeRAM+22

    lda #$38
    sta timeRAM+3
    lda #$30
    sta timeRAM+7
    lda #$28
    sta timeRAM+11
    lda #$20
    sta timeRAM+15
    lda #$18
    sta timeRAM+19
    lda #$10
    sta timeRAM+23

    jmp MAIN
    
;;;;;;;;;;;;;;;;;;;;;;;
;;;   SUBROUTINES   ;;;
;;;;;;;;;;;;;;;;;;;;;;;

timekeeping:
    ldx #$00

    dec tick
    bne timekeepingDone
    lda #$3C
    sta tick

    inc seconds
    lda seconds
    cmp #$3C
    bne timekeepingDone
    stx seconds
    lda tick            ; Add 6 cycles per second to get 60.1 Hz
    clc
    adc #$06
    sta tick

    inc minutes
    lda minutes
    cmp #$3C
    bne timekeepingDone
    stx minutes
    lda tick            ; Actual framerate is ~60.098 Hz which is another 7.2 cycles per hour
    sec
    sbc #$07
    sta tick
    
    inc hours
    lda hours
    cmp #$0D
    bne timekeepingDone
    inx
    stx hours
    dec tick            ; .2 cycles per hour is 4.8 cycles per day so subtract 2 cycles per half day
    dec tick            ;  for a remainder of .8 cycles per day or ~4.9 seconds per year too fast
timekeepingDone:        ;  not accounting for crystal drift.
    rts
    
timeRAM = $0280

displayTime:
    lda seconds
    and #$0F
    tax
    lda digits,x
    sta timeRAM+1
    lda seconds
    lsr
    lsr
    lsr
    lsr
    tax
    lda digits,x
    sta timeRAM+5

    lda minutes
    and #$0F
    tax
    lda digits,x
    sta timeRAM+9
    lda minutes
    lsr
    lsr
    lsr
    lsr
    tax
    lda digits,x
    sta timeRAM+13

    lda hours
    and #$0F
    tax
    lda digits,x
    sta timeRAM+17
    lda hours
    lsr
    lsr
    lsr
    lsr
    tax
    lda digits,x
    sta timeRAM+21
displayTimeDone:
    rts

digits:
    .db $a0,$a1,$a2,$a3,$a4,$a5,$a6,$a7,$a8,$a9,$aa,$ab,$ac,$ad,$ae,$af

latchController:
    lda #$01
    sta CONTROLLER_1
    lda #$00
    sta CONTROLLER_1

    lda buttons
    sta oldButtons

    ldx #$08
@loop
    lda CONTROLLER_1
    lsr
    rol buttons
    dex
    bne @loop
latchControllerDone:
    rts
    
incMins:
    lda buttons
    and #%00001000
    beq incMinsDone
    
    lda oldButtons
    and #%00001000
    bne incMinsDone
    
    inc minutes
    lda minutes
    cmp #$3C
    bne incMinsDone
    lda #$00
    sta minutes
incMinsDone:
    rts
    
decMins:
    lda buttons
    and #%00000100
    beq decMinsDone
    
    lda oldButtons
    and #%00000100
    bne decMinsDone

    dec minutes
    bpl decMinsDone
    lda #$3B
    sta minutes
decMinsDone:
    rts
    
incHours:
    lda buttons
    and #%00000010
    beq incHoursDone
    
    lda oldButtons
    and #%00000010
    bne incHoursDone
    
    inc hours
    lda hours
    cmp #$0D
    bne incHoursDone
    lda #$01
    sta hours
incHoursDone:
    rts
    
decHours:
    lda buttons
    and #%00000001
    beq decHoursDone
    
    lda oldButtons
    and #%00000001
    bne decHoursDone

    dec hours
    bne decHoursDone
    lda #$0C
    sta hours
decHoursDone:
    rts
    
clearSecs:
    lda buttons
    and #%10000000
    beq clearSecsDone
    
    lda oldButtons
    and #%10000000
    bne clearSecsDone
    
    lda #$00
    sta seconds
    lda #$3C
    sta tick
clearSecsDone:
    rts


;;;;;;;;;;;;;;;;
;;;   MAIN   ;;;
;;;;;;;;;;;;;;;;

MAIN:
    inc sleeping
loop:
    lda sleeping
    bne loop
    
    jsr incMins
    jsr decMins
    jsr incHours
    jsr decHours
    jsr clearSecs
    
    jsr displayTime

    jmp MAIN
MAINdone:

;;;;;;;;;;;;;;;
;;;   NMI   ;;;
;;;;;;;;;;;;;;;

NMI:
    pha
    txa
    pha
    tya
    pha

    lda #$00
    sta $2003
    lda #$02
    sta $4014

    jsr timekeeping
    jsr latchController

    lda #$00
    sta PPU_Address
    sta PPU_Address

    lda #$00
    sta PPU_Scroll
    sta PPU_Scroll

    lda softPPU_Control
    sta PPU_Control
    lda softPPU_Mask
    sta PPU_Mask
    dec sleeping

    pla
    tay
    pla
    tax
    pla
    rti
NMIdone:

;;;;;;;;;;;;;;;;;;
;;;   TABLES   ;;;
;;;;;;;;;;;;;;;;;;
    .align $100
    
background:
    .db $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F
    .db $0F, $00, $01, $02, $00, $01, $02, $0F, $0F, $00, $01, $02, $00, $01, $02, $0F
    .db $0F, $03, $0F, $05, $03, $0F, $05, $0F, $0F, $03, $0F, $05, $03, $0F, $05, $0F
    .db $0F, $06, $07, $08, $06, $07, $08, $0F, $0F, $06, $07, $08, $06, $07, $08, $0F
    .db $0F, $09, $0F, $0B, $09, $0F, $0B, $0F, $0F, $09, $0F, $0B, $09, $0F, $0B, $0F
    .db $0F, $0C, $0D, $0E, $0C, $0D, $0E, $0F, $0F, $0C, $0D, $0E, $0C, $0D, $0E, $0F
    .db $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F
    .db $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F
    .db $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F
    .db $0F, $00, $01, $02, $00, $01, $02, $0F, $0F, $00, $01, $02, $00, $01, $02, $0F
    .db $0F, $03, $0F, $05, $03, $0F, $05, $0F, $0F, $03, $0F, $05, $03, $0F, $05, $0F
    .db $0F, $06, $07, $08, $06, $07, $08, $0F, $0F, $06, $07, $08, $06, $07, $08, $0F
    .db $0F, $09, $0F, $0B, $09, $0F, $0B, $0F, $0F, $09, $0F, $0B, $09, $0F, $0B, $0F
    .db $0F, $0C, $0D, $0E, $0C, $0D, $0E, $0F, $0F, $0C, $0D, $0E, $0C, $0D, $0E, $0F
    .db $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F
    .db $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F

attributes:
    .db $00, $40, $AF, $F0, $F0, $F0, $F0, $F0, $00, $CF, $A0, $9F, $FF, $CF, $3F, $FF
    .db $00, $8F, $FF, $90, $FF, $FF, $FF, $FF, $00, $00, $00, $00, $00, $00, $00, $00
    .db $00, $40, $00, $10, $00, $40, $00, $10, $00, $CF, $00, $FF, $00, $CF, $00, $FF
    .db $00, $8F, $00, $2F, $00, $8F, $00, $2F, $00, $00, $00, $00, $00, $00, $00, $00

;     .db %00000000, %01000000, %00000000, %00010000, %01000000, %00000000, %00010000, %11111111
;     .db %11111111, %11111111, %11111111, %11111111, %11111111, %11111111, %11111111, %11111111
;     .db %11111111, %11111111, %11111111, %11111111, %11111111, %11111111, %11111111, %11111111
;     .db %11111111, %11111111, %11111111, %11111111, %11111111, %11111111, %11111111, %11111111
;     .db %11111111, %11111111, %11111111, %11111111, %11111111, %11111111, %11111111, %11111111
;     .db %11111111, %11111111, %11111111, %11111111, %11111111, %11111111, %11111111, %11111111
;     .db %11111111, %11111111, %11111111, %11111111, %11111111, %11111111, %11111111, %11111111
;     .db %11111111, %11111111, %11111111, %11111111, %11111111, %11111111, %11111111, %11111111

palette:
    .db $0F,$0F,$0F,$0F,  $0F,$20,$20,$0F,  $0F,$20,$0F,$20,  $0F,$20,$20,$20   ;;background palette
    .db $0F,$20,$17,$07,  $0F,$0F,$10,$00,  $0F,$1C,$15,$14,  $0F,$02,$38,$3C   ;;sprite palette

    ;;;  00   01   02   03   04   05   06   07   08   09   0A   0B   0C   0D   0E   0F   10   11   12
topLeft:
    .db $00, $02, $04, $20, $22, $24, $40, $42, $44, $60, $62, $64, $80, $82, $84, $EE, $EF, $FE, $FF

topRight:
    .db $01, $03, $05, $21, $23, $25, $41, $43, $45, $61, $62, $65, $81, $83, $85, $EE, $EF, $FE, $FF

bottomLeft:
    .db $10, $12, $14, $30, $32, $34, $50, $52, $54, $70, $72, $74, $90, $92, $94, $EE, $EF, $FE, $FF

bottomRight:
    .db $11, $13, $15, $31, $33, $35, $51, $53, $55, $71, $73, $75, $91, $93, $95, $EE, $EF, $FE, $FF


sprite_Y:
    .db $2F, $37, $2F, $37, $2F, $37, $2F, $37, $2F, $37, $2F, $37, $2F, $37, $2F, $37

sprite_Tile:
    .db $06, $06, $06, $06, $06, $06, $06, $06, $06, $06, $06, $06, $06, $06, $06, $06

sprite_Attrib:
    .db $00, $80, $40, $C0, $00, $80, $40, $C0, $00, $80, $40, $C0, $00, $80, $40, $C0

sprite_X:
    .db $18, $18, $30, $30, $48, $48, $60, $60, $98, $98, $B0, $B0, $C8, $C8, $E0, $E0


;;;;;;;;;;;;;;;;;;;
;;;   VECTORS   ;;;
;;;;;;;;;;;;;;;;;;;

    .pad $FFFA

    .dw NMI
    .dw RESET
    .dw 0


;;;;;;;;;;;;;;;;;;;
;;;   CHR-ROM   ;;;
;;;;;;;;;;;;;;;;;;;

    .incbin "clock.chr"
