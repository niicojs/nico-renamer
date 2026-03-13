import { Workbook } from '@niicojs/excel';
import { existsSync, readdirSync, readFileSync, renameSync, writeFileSync } from 'fs';
import { join } from 'path';

type ExcelData = {
  nom: string;
  concentration: number;
  maj: number;
};

const current = import.meta.dirname;
const dir = process.argv.at(2) ?? current;

console.info('┌──────────────┐');
console.info('│ nico renamer │');
console.info('└──────────────┘');

console.info('Répertoire:', dir);

const excelfile = join(dir, 'rename.xlsx');

const re = new RegExp(/(?<=^\[)(\d*\.?\d*)(?=[^\]]*\])/);

if (existsSync(excelfile)) {
  console.info('Fichier excel existant, on renomme.');

  const workbook = await Workbook.fromFile(excelfile);
  const data = workbook.sheet(0).toJson() as ExcelData[];

  for (const file of data) {
    if (existsSync(join(dir, file.nom))) {
      const name = file.nom.replace(re, file.maj.toString());
      if (name !== file.nom) {
        renameSync(join(dir, file.nom), join(dir, name));

        const content = readFileSync(join(dir, name), 'utf-8');
        const newContent = content.replace(
          /Sample concentration: (\d+.\d+)/,
          `Sample concentration: ${file.maj.toString()}`,
        );
        writeFileSync(join(dir, name), newContent);
      }
    }
  }
} else {
  console.info('Fichier excel non existant, on le crée.');

  const files = readdirSync(dir).filter((f) => f.endsWith('.txt'));

  const data = Array.from(files).map((f) => {
    const val = f.match(re)?.[1] || 0;
    return {
      nom: f,
      concentration: val,
      maj: val,
    };
  });

  const workbook = Workbook.create();
  workbook.addSheetFromData({
    name: 'rename',
    data,
  });
  await workbook.toFile(excelfile);
}

console.info('Ok.');
