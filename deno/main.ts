import { join, dirname } from '@std/path';
import { existsSync } from 'jsr:@std/fs/exists';

// @deno-types="https://cdn.sheetjs.com/xlsx-0.20.3/package/types/index.d.ts"
import * as XLSX from 'https://cdn.sheetjs.com/xlsx-0.20.3/package/xlsx.mjs';

type ExcelData = {
  nom: string;
  concentration: number;
  maj: number;
};

const current = dirname(Deno.execPath());
const dir = Deno.args.at(0) ?? current;

console.info('┌──────────────┐');
console.info('│ nico renamer │');
console.info('└──────────────┘');

console.info('Répertoire:', dir);

const excelfile = join(dir, 'rename.xlsx');

const re = new RegExp(/(?<=^\[)(\d*\.?\d*)(?=[^\]]*\])/);

if (existsSync(excelfile)) {
  console.info('Fichier excel existant, on renomme.');

  const workbook = XLSX.readFile(excelfile);
  const worksheet = workbook.Sheets[workbook.SheetNames[0]];
  const data = XLSX.utils.sheet_to_json(worksheet) as ExcelData[];

  for (const file of data) {
    if (existsSync(join(dir, file.nom))) {
      const name = file.nom.replace(re, file.maj.toString());
      if (name !== file.nom) {
        Deno.renameSync(join(dir, file.nom), join(dir, name));

        const content = Deno.readTextFileSync(join(dir, name));
        const newContent = content.replace(
          /Sample concentration: (\d+.\d+)/,
          `Sample concentration: ${file.maj.toString()}`,
        );
        Deno.writeTextFileSync(join(dir, name), newContent);
      }
    }
  }
} else {
  console.info('Fichier excel non existant, on le crée.');

  const files = Deno.readDirSync(dir).filter(
    (f) => !f.isDirectory && f.name.startsWith('[') && f.name.endsWith('.txt'),
  );

  const data = Array.from(files).map((f) => {
    const val = +(f.name.match(re)?.[1] || 0);
    return {
      nom: f.name,
      concentration: val,
      maj: val,
    };
  });

  const workbook = XLSX.utils.book_new();
  const worksheet = XLSX.utils.json_to_sheet(data);
  XLSX.utils.book_append_sheet(workbook, worksheet, 'data');
  XLSX.writeFile(workbook, excelfile);
}

console.info('Ok.');
