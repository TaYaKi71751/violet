/**
 * Ported from violet/lib/component/query_translate.dart
 * Translates search query DSL to SQL for HitomiColumnModel.
 */

export function translateQuery(
  query: string,
  page: number,
  pageSize: number,
): { sql: string; countSql: string } {
  query = query.trim();

  // Numeric ID query
  const nn = parseInt(query.split(' ')[0]);
  if (!isNaN(nn) && query.split(' ')[0] === String(nn)) {
    return {
      sql: `SELECT * FROM HitomiColumnModel WHERE Id=${nn}`,
      countSql: `SELECT COUNT(*) as cnt FROM HitomiColumnModel WHERE Id=${nn}`,
    };
  }

  if (query === '') {
    const base = 'SELECT * FROM HitomiColumnModel WHERE ExistOnHitomi=1';
    return {
      sql: `${base} ORDER BY Id DESC LIMIT ${pageSize} OFFSET ${page * pageSize}`,
      countSql: `SELECT COUNT(*) as cnt FROM HitomiColumnModel WHERE ExistOnHitomi=1`,
    };
  }

  const tokens = splitTokens(query)
    .map((x) => x.trim())
    .filter((x) => x !== '');
  const translator = new QueryTranslator(tokens);
  const where = translator.parseExpression();

  const baseSql = `SELECT * FROM HitomiColumnModel WHERE ${where} AND ExistOnHitomi=1`;
  return {
    sql: `${baseSql} ORDER BY Id DESC LIMIT ${pageSize} OFFSET ${page * pageSize}`,
    countSql: `SELECT COUNT(*) as cnt FROM HitomiColumnModel WHERE ${where} AND ExistOnHitomi=1`,
  };
}

function splitTokens(input: string): string[] {
  const result: string[] = [];
  let builder = '';

  for (let i = 0; i < input.length; i++) {
    const ch = input[i];
    if (ch === ' ') {
      result.push(builder);
      builder = '';
    } else if (ch === '(' || ch === ')') {
      result.push(builder);
      builder = '';
      result.push(ch);
    } else {
      builder += ch;
    }
  }

  result.push(builder);
  return result;
}

class QueryTranslator {
  private tokens: string[];
  private index = 0;

  constructor(tokens: string[]) {
    this.tokens = tokens;
  }

  parseExpression(): string {
    if (this.index >= this.tokens.length) return '';

    let token = this.nextToken();
    let where = '';
    let negative = false;

    if (token.startsWith('-')) {
      negative = true;
      if (token === '-') {
        token = this.nextToken();
      } else {
        token = token.substring(1);
      }
    }

    if (token.includes(':')) {
      where += this.parseTag(token, negative);
    } else if (
      token.startsWith('page') &&
      (token.includes('>') || token.includes('=') || token.includes('<'))
    ) {
      where += this.parsePageExpression(token);
    } else if (token === '(') {
      where += this.parseParentheses(token, negative);
      where += this.parseExpression();
      where += this.nextToken(); // closing ')'
      if (this.hasMoreTokens()) {
        where += this.parseLogicalExpression();
      }
    } else if (token === ')') {
      return token;
    } else {
      where += this.parseTitle(token, negative);
    }

    if (this.hasMoreTokens() && this.lookAhead() !== ')') {
      where += this.parseLogicalExpression();
    }

    return where;
  }

  private parseTag(token: string, negative: boolean): string {
    const ss = token.split(':');
    const column = findColumnByTag(ss[0]);
    if (column === '') return '';

    let name = '';
    switch (ss[0]) {
      case 'male':
      case 'female':
        name = `|${token.replace(/_/g, ' ')}|`;
        break;
      case 'tag':
      case 'series':
      case 'artist':
      case 'character':
      case 'group':
        name = `|${ss[1].replace(/_/g, ' ')}|`;
        break;
      case 'uploader':
        name = ss[1];
        break;
      case 'lang':
      case 'type':
      case 'class':
        name = ss[1].replace(/_/g, ' ');
        break;
    }

    let compare = `${column} LIKE '%${escapeSql(name)}%'`;
    if (column === 'Uploader') compare += ' COLLATE NOCASE';

    return negative ? `(${compare}) IS NOT 1` : compare;
  }

  private parsePageExpression(token: string): string {
    const re = /page([\=\<\>]{1,2})(\d+)/;
    const match = token.match(re);
    if (match) {
      return `Files ${match[1]} ${match[2]}`;
    }
    return '';
  }

  private parseParentheses(token: string, negative: boolean): string {
    return negative ? `NOT ${token}` : token;
  }

  private parseTitle(token: string, negative: boolean): string {
    const escaped = escapeSql(token);
    return negative
      ? `Title NOT LIKE '%${escaped}%'`
      : `Title LIKE '%${escaped}%'`;
  }

  private parseLogicalExpression(): string {
    const next = this.lookAhead();
    let op: string;
    if (next.toLowerCase() === 'or') {
      this.nextToken();
      op = 'OR';
    } else {
      op = 'AND';
    }
    return ` ${op} ${this.parseExpression()}`;
  }

  private nextToken(): string {
    return this.tokens[this.index++];
  }

  private lookAhead(): string {
    return this.index < this.tokens.length ? this.tokens[this.index] : '';
  }

  private hasMoreTokens(): boolean {
    return this.index < this.tokens.length;
  }
}

function findColumnByTag(tag: string): string {
  switch (tag) {
    case 'male':
    case 'female':
    case 'tag':
      return 'Tags';
    case 'lang':
      return 'Language';
    case 'series':
      return 'Series';
    case 'artist':
      return 'Artists';
    case 'group':
      return 'Groups';
    case 'uploader':
      return 'Uploader';
    case 'character':
      return 'Characters';
    case 'type':
      return 'Type';
    case 'class':
      return 'Class';
    default:
      return tag;
  }
}

function escapeSql(str: string): string {
  return str.replace(/'/g, "''");
}
