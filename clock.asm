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

    jmp MAIN
    
;;;;;;;;;;;;;;;;;;;;;;;
;;;   SUBROUTINES   ;;;
;;;;;;;;;;;;;;;;;;;;;;;



;;;;;;;;;;;;;;;;
;;;   MAIN   ;;;
;;;;;;;;;;;;;;;;

MAIN:
    inc sleeping
loop:
    lda sleeping
    bne loop

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
    .db $0F,$27,$17,$07,  $0F,$20,$10,$00,  $0F,$1C,$15,$14,  $0F,$02,$38,$3C   ;;sprite palette

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
