"""Extrae los parametros de juego de UCS de libMPX.so (lib/arm64-v8a de la division config.arm64_v8a del APK de Ultimate
Clash Soccer) leyendo el codigo ARM64 de la funcion que carga la configuracion (sin simbolo; prologo en 0x5845b4).

Patron por parametro (comprobado en las 210 lecturas):
    ADRP x1 / ADD x1  -> direccion de la cadena con el NOMBRE del parametro
    MOV  w2, #valor    -> VALOR POR DEFECTO (o MOV w2, wzr = 0; o ADD w2, w19, #... = valor calculado)
    ADD  x0, sp, #off  -> objeto de la seccion de configuracion
    BL   0x5e9030      -> lectura de un entero por nombre (o 0x5e86d8 para un texto)
    STR  w0, [xN, #campo] -> campo de la estructura donde queda el valor
No ejecuta nada: solo desensambla con capstone (pip install capstone).

Uso: python3 tools/transfer/ucs_params_extract.py <libMPX.so> > parametros.csv
Columnas: parametro, valor_defecto, origen_valor, q12, campo, funcion_lectura, direccion_str, objeto_x0
"""
import re
import sys

from capstone import CS_ARCH_ARM64, CS_MODE_ARM, Cs

START = 0x584800
END = 0x586400


def cstr(d, a):
    e = d.find(b"\0", a)
    try:
        return d[a:e].decode()
    except UnicodeDecodeError:
        return None


def main():
    d = open(sys.argv[1], "rb").read()
    md = Cs(CS_ARCH_ARM64, CS_MODE_ARM)
    regs = {}
    w = {}       # valores conocidos de registros w (w19 se carga una vez: 0x14000)
    w2 = None
    w2_src = ""
    x1 = None
    x0 = ""
    pending = None   # lectura hecha (BL), a la espera del STR que guarda el resultado
    alias = None     # registro al que se copio w0 (mov wN, w0) antes de guardarlo
    out = []
    for ins in md.disasm(d[START:END], START):
        m, o = ins.mnemonic, ins.op_str
        if m == "adrp":
            r, imm = o.split(", #")
            regs[r] = int(imm, 16)
        elif m == "add" and re.match(r"x\d+, x\d+, #0x[0-9a-f]+$", o):
            rd, rn, imm = o.split(", ")
            if rn in regs:
                regs[rd] = regs[rn] + int(imm[1:], 16)
            if rd == "x1":
                x1 = regs.get(rd)
        elif m == "add" and o.startswith("x0, sp, #"):
            x0 = "sp+" + o.split("#")[1]
        elif m in ("mov", "movz") and re.match(r"w19, #", o):
            w["w19"] = int(o.split("#")[1], 0)
        elif m == "movk" and o.startswith("w19, #"):
            parts = o.split(", ")
            sh = int(parts[2].split("#")[1]) if len(parts) > 2 else 0
            w["w19"] = (w.get("w19", 0) & ~(0xFFFF << sh)) | (int(parts[1][1:], 0) << sh)
        elif m in ("mov", "movz", "movn") and o.startswith("w2, #"):
            w2 = int(o.split("#")[1], 0)
            w2_src = "constante"
        elif m == "movk" and o.startswith("w2, #"):
            # MOV + MOVK: el valor se arma en dos instrucciones (puede haber otras en medio, p. ej. el STR anterior).
            parts = o.split(", ")
            sh = int(parts[2].split("#")[1]) if len(parts) > 2 else 0
            w2 = ((w2 or 0) & ~(0xFFFF << sh)) | (int(parts[1][1:], 0) << sh)
            w2_src = "constante (mov + movk)"
        elif m == "mov" and o == "w2, wzr":
            w2 = 0
            w2_src = "registro cero (wzr)"
        elif m == "add" and re.match(r"w2, w19, #", o):
            parts = o.split(", ")
            imm = int(parts[2][1:], 0)
            if len(parts) > 3 and "lsl" in parts[3]:
                imm <<= int(parts[3].split("#")[1])
            w2 = w["w19"] + imm if "w19" in w else None
            w2_src = "calculado: w19 (0x%x) + 0x%x" % (w.get("w19", 0), imm)
        elif m == "mov" and o.startswith("w2, w"):
            w2 = None
            w2_src = "registro " + o.split(", ")[1]
        elif m == "mov" and re.match(r"w\d+, w0$", o) and pending is not None:
            alias = o.split(", ")[0]
        elif m == "bl":
            target = o.lstrip("#")
            if target in ("0x5e9030", "0x5e86d8") and x1 is not None:
                name = cstr(d, x1)
                if name and re.match(r"^[A-Za-z][A-Za-z0-9_]+$", name):
                    v = w2 if target == "0x5e9030" else None
                    if v is not None and v >= 1 << 31:
                        v -= 1 << 32
                    src = w2_src if target == "0x5e9030" else "texto (lectura 0x5e86d8)"
                    pending = [name, v, src, target, x0]
                    alias = None
                x1 = None
            # El llamado pisa w2 (registro no preservado).
            w2 = None
            w2_src = ""
        elif m == "str" and pending is not None and (o.startswith("w0, [") or (alias is not None and o.startswith(alias + ", ["))):
            off = o.split("#")[1].rstrip("]") if "#" in o else "0"
            name, v, src, target, obj = pending
            out.append((name, v, src, off, target, hex(ins.address), obj))
            pending = None
            alias = None
    print("parametro,valor_defecto,origen_valor,q12,campo,funcion_lectura,direccion_str,objeto_x0")
    for name, v, src, off, target, addr, obj in out:
        q = "" if v is None else "%.4f" % (v / 4096.0)
        print("%s,%s,%s,%s,%s,%s,%s,%s" % (name, "" if v is None else v, src, q, off, target, addr, obj))
    sys.stderr.write("%d parametros\n" % len(out))


if __name__ == "__main__":
    main()
