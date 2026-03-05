"use strict";
var __assign = (this && this.__assign) || function () {
    __assign = Object.assign || function(t) {
        for (var s, i = 1, n = arguments.length; i < n; i++) {
            s = arguments[i];
            for (var p in s) if (Object.prototype.hasOwnProperty.call(s, p))
                t[p] = s[p];
        }
        return t;
    };
    return __assign.apply(this, arguments);
};
var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
var __generator = (this && this.__generator) || function (thisArg, body) {
    var _ = { label: 0, sent: function() { if (t[0] & 1) throw t[1]; return t[1]; }, trys: [], ops: [] }, f, y, t, g = Object.create((typeof Iterator === "function" ? Iterator : Object).prototype);
    return g.next = verb(0), g["throw"] = verb(1), g["return"] = verb(2), typeof Symbol === "function" && (g[Symbol.iterator] = function() { return this; }), g;
    function verb(n) { return function (v) { return step([n, v]); }; }
    function step(op) {
        if (f) throw new TypeError("Generator is already executing.");
        while (g && (g = 0, op[0] && (_ = 0)), _) try {
            if (f = 1, y && (t = op[0] & 2 ? y["return"] : op[0] ? y["throw"] || ((t = y["return"]) && t.call(y), 0) : y.next) && !(t = t.call(y, op[1])).done) return t;
            if (y = 0, t) op = [op[0] & 2, t.value];
            switch (op[0]) {
                case 0: case 1: t = op; break;
                case 4: _.label++; return { value: op[1], done: false };
                case 5: _.label++; y = op[1]; op = [0]; continue;
                case 7: op = _.ops.pop(); _.trys.pop(); continue;
                default:
                    if (!(t = _.trys, t = t.length > 0 && t[t.length - 1]) && (op[0] === 6 || op[0] === 2)) { _ = 0; continue; }
                    if (op[0] === 3 && (!t || (op[1] > t[0] && op[1] < t[3]))) { _.label = op[1]; break; }
                    if (op[0] === 6 && _.label < t[1]) { _.label = t[1]; t = op; break; }
                    if (t && _.label < t[2]) { _.label = t[2]; _.ops.push(op); break; }
                    if (t[2]) _.ops.pop();
                    _.trys.pop(); continue;
            }
            op = body.call(thisArg, _);
        } catch (e) { op = [6, e]; y = 0; } finally { f = t = 0; }
        if (op[0] & 5) throw op[1]; return { value: op[0] ? op[1] : void 0, done: true };
    }
};
var __rest = (this && this.__rest) || function (s, e) {
    var t = {};
    for (var p in s) if (Object.prototype.hasOwnProperty.call(s, p) && e.indexOf(p) < 0)
        t[p] = s[p];
    if (s != null && typeof Object.getOwnPropertySymbols === "function")
        for (var i = 0, p = Object.getOwnPropertySymbols(s); i < p.length; i++) {
            if (e.indexOf(p[i]) < 0 && Object.prototype.propertyIsEnumerable.call(s, p[i]))
                t[p[i]] = s[p[i]];
        }
    return t;
};
var __spreadArray = (this && this.__spreadArray) || function (to, from, pack) {
    if (pack || arguments.length === 2) for (var i = 0, l = from.length, ar; i < l; i++) {
        if (ar || !(i in from)) {
            if (!ar) ar = Array.prototype.slice.call(from, 0, i);
            ar[i] = from[i];
        }
    }
    return to.concat(ar || Array.prototype.slice.call(from));
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.getCachedRecipesByIngredients = getCachedRecipesByIngredients;
exports.saveRecipesToCache = saveRecipesToCache;
exports.getPopularRecipes = getPopularRecipes;
var supabase_1 = require("./supabase");
function normalizeIngredients(ingredients) {
    return ingredients.map(function (i) { return i.toLowerCase().trim(); }).filter(Boolean);
}
function stemWord(word) {
    var suffixes = ['ları', 'leri', 'ler', 'lar', 'ies', 'ing', 'ed', 'es', 's'];
    var w = word;
    for (var _i = 0, suffixes_1 = suffixes; _i < suffixes_1.length; _i++) {
        var suffix = suffixes_1[_i];
        if (w.length > suffix.length + 2 && w.endsWith(suffix)) {
            w = w.slice(0, -suffix.length);
            break;
        }
    }
    return w;
}
function ingredientMatches(userWord, recipeNames) {
    var word = userWord.toLowerCase().trim();
    if (word.length < 2)
        return false;
    var stemmed = stemWord(word);
    for (var _i = 0, recipeNames_1 = recipeNames; _i < recipeNames_1.length; _i++) {
        var name_1 = recipeNames_1[_i];
        if (name_1 === word)
            return true;
        if (name_1.includes(word) || word.includes(name_1))
            return true;
        var nameStemmed = stemWord(name_1);
        if (stemmed.length >= 3 && nameStemmed.length >= 3) {
            if (nameStemmed.includes(stemmed) || stemmed.includes(nameStemmed))
                return true;
        }
    }
    return false;
}
function getCacheTable(language) {
    return language === 'tr' ? 'ai_cache_turkish' : 'ai_cache';
}
function extractIngredientNames(row) {
    var names = [];
    var data = typeof row.recipe_data === 'string'
        ? (function () { try {
            return JSON.parse(row.recipe_data);
        }
        catch (_a) {
            return {};
        } })()
        : (row.recipe_data || {});
    if (data.ingredients && Array.isArray(data.ingredients)) {
        for (var _i = 0, _a = data.ingredients; _i < _a.length; _i++) {
            var ing = _a[_i];
            var n = (typeof ing === 'string' ? ing : (ing.name || '')).toLowerCase().trim();
            if (n)
                names.push(n);
        }
    }
    if (data.required_extra_ingredients && Array.isArray(data.required_extra_ingredients)) {
        for (var _b = 0, _c = data.required_extra_ingredients; _b < _c.length; _b++) {
            var extra = _c[_b];
            var n = (typeof extra === 'string' ? extra : '').toLowerCase().trim();
            if (n)
                names.push(n);
        }
    }
    if (row.required_ingredients) {
        var ri = row.required_ingredients;
        var parsed = [];
        if (Array.isArray(ri)) {
            parsed = ri;
        }
        else if (typeof ri === 'string') {
            parsed = ri.replace(/[{}\[\]"]/g, '').split(',');
        }
        for (var _d = 0, parsed_1 = parsed; _d < parsed_1.length; _d++) {
            var p = parsed_1[_d];
            var n = p.toLowerCase().trim();
            if (n && !names.includes(n))
                names.push(n);
        }
    }
    if (row.optional_ingredients) {
        var oi = row.optional_ingredients;
        var parsed = [];
        if (Array.isArray(oi)) {
            parsed = oi;
        }
        else if (typeof oi === 'string') {
            parsed = oi.replace(/[{}\[\]"]/g, '').split(',');
        }
        for (var _e = 0, parsed_2 = parsed; _e < parsed_2.length; _e++) {
            var p = parsed_2[_e];
            var n = p.toLowerCase().trim();
            if (n && !names.includes(n))
                names.push(n);
        }
    }
    return names.filter(Boolean);
}
function getCachedRecipesByIngredients(userIngredients_1) {
    return __awaiter(this, arguments, void 0, function (userIngredients, limit, language) {
        var normalized, table, _a, allCached, error, inputWords, _i, normalized_1, ing, _b, _c, part, uniqueInputWords_1, scored, rawCount, minForGood_1, minForPartial_1, goodMatches, partialMatches, top_1, topData, collected, usedIds, _d, goodMatches_1, row, recipe, _e, partialMatches_1, row, recipe, err_1;
        if (limit === void 0) { limit = 2; }
        if (language === void 0) { language = 'en'; }
        return __generator(this, function (_f) {
            switch (_f.label) {
                case 0:
                    normalized = normalizeIngredients(userIngredients);
                    if (normalized.length === 0)
                        return [2 /*return*/, []];
                    table = getCacheTable(language);
                    _f.label = 1;
                case 1:
                    _f.trys.push([1, 3, , 4]);
                    return [4 /*yield*/, supabase_1.supabase
                            .from(table)
                            .select('*')
                            .order('created_at', { ascending: false })
                            .limit(300)];
                case 2:
                    _a = _f.sent(), allCached = _a.data, error = _a.error;
                    if (error) {
                        console.error('[CACHE] Query error:', error.message, '| code:', error.code);
                        return [2 /*return*/, []];
                    }
                    if (!allCached || allCached.length === 0) {
                        console.log('[CACHE] No rows found in table:', table);
                        return [2 /*return*/, []];
                    }
                    console.log('[CACHE] Fetched', allCached.length, 'rows from', table);
                    inputWords = [];
                    for (_i = 0, normalized_1 = normalized; _i < normalized_1.length; _i++) {
                        ing = normalized_1[_i];
                        inputWords.push(ing);
                        for (_b = 0, _c = ing.split(/[\s,]+/); _b < _c.length; _b++) {
                            part = _c[_b];
                            if (part.length >= 2 && !inputWords.includes(part))
                                inputWords.push(part);
                        }
                    }
                    uniqueInputWords_1 = __spreadArray([], new Set(inputWords), true);
                    scored = allCached.map(function (row) {
                        var ingredientNames = extractIngredientNames(row);
                        var matchCount = 0;
                        var matchedWords = [];
                        for (var _i = 0, uniqueInputWords_2 = uniqueInputWords_1; _i < uniqueInputWords_2.length; _i++) {
                            var word = uniqueInputWords_2[_i];
                            if (ingredientMatches(word, ingredientNames)) {
                                matchCount++;
                                matchedWords.push(word);
                            }
                        }
                        var matchRatio = uniqueInputWords_1.length > 0 ? matchCount / uniqueInputWords_1.length : 0;
                        return { row: row, matchCount: matchCount, matchedWords: matchedWords, ingredientNames: ingredientNames, matchRatio: matchRatio };
                    });
                    rawCount = normalized.length;
                    minForGood_1 = Math.max(1, Math.ceil(rawCount * 0.4));
                    minForPartial_1 = Math.max(1, Math.ceil(rawCount * 0.2));
                    goodMatches = scored
                        .filter(function (s) { return s.ingredientNames.length > 0 && s.matchCount >= minForGood_1; })
                        .sort(function (a, b) {
                        if (b.matchCount !== a.matchCount)
                            return b.matchCount - a.matchCount;
                        return b.matchRatio - a.matchRatio;
                    });
                    partialMatches = scored
                        .filter(function (s) { return s.ingredientNames.length > 0 && s.matchCount >= minForPartial_1 && s.matchCount < minForGood_1; })
                        .sort(function (a, b) { return b.matchCount - a.matchCount; });
                    console.log('[CACHE] Input:', normalized.join(', '), '| words:', uniqueInputWords_1.join(', '), '| rawCount:', rawCount, '| minGood:', minForGood_1, '| minPartial:', minForPartial_1);
                    console.log('[CACHE] Good:', goodMatches.length, '| Partial:', partialMatches.length);
                    if (goodMatches.length > 0) {
                        top_1 = goodMatches[0];
                        topData = typeof top_1.row.recipe_data === 'object' ? top_1.row.recipe_data : {};
                        console.log('[CACHE] Top good:', topData.title || top_1.row.recipe_id, '| matched:', top_1.matchedWords.join(','), '| recipe ingredients:', top_1.ingredientNames.slice(0, 8).join(','));
                    }
                    collected = [];
                    usedIds = new Set();
                    for (_d = 0, goodMatches_1 = goodMatches; _d < goodMatches_1.length; _d++) {
                        row = goodMatches_1[_d].row;
                        if (collected.length >= limit)
                            break;
                        recipe = rowToRecipe(row);
                        if (!usedIds.has(recipe.id)) {
                            collected.push(recipe);
                            usedIds.add(recipe.id);
                        }
                    }
                    for (_e = 0, partialMatches_1 = partialMatches; _e < partialMatches_1.length; _e++) {
                        row = partialMatches_1[_e].row;
                        if (collected.length >= limit)
                            break;
                        recipe = rowToRecipe(row);
                        if (!usedIds.has(recipe.id)) {
                            collected.push(recipe);
                            usedIds.add(recipe.id);
                        }
                    }
                    console.log('[CACHE] Returning', collected.length, 'cached recipes');
                    return [2 /*return*/, collected];
                case 3:
                    err_1 = _f.sent();
                    console.error('[CACHE] Error:', err_1);
                    return [2 /*return*/, []];
                case 4: return [2 /*return*/];
            }
        });
    });
}
function rowToRecipe(row) {
    var data = typeof row.recipe_data === 'string'
        ? JSON.parse(row.recipe_data)
        : (row.recipe_data || {});
    return {
        id: data.id || row.recipe_id || "cache_".concat(row.id),
        title: data.title || row.title || 'Untitled',
        calories: data.calories || '300-400',
        cuisine: data.cuisine || row.cuisine || 'International',
        difficulty: data.difficulty || row.difficulty || 'Medium',
        description: data.description || '',
        servings: data.servings || row.servings || 2,
        ingredients: data.ingredients || [],
        spices: data.spices || [],
        required_extra_ingredients: data.required_extra_ingredients || [],
        steps: data.steps || [],
    };
}
function saveRecipesToCache(recipes_1) {
    return __awaiter(this, arguments, void 0, function (recipes, language) {
        var table, rows, _a, data, error, minimalRows, _b, retryData, retryError;
        var _c;
        if (language === void 0) { language = 'en'; }
        return __generator(this, function (_d) {
            switch (_d.label) {
                case 0:
                    if (recipes.length === 0)
                        return [2 /*return*/];
                    table = getCacheTable(language);
                    rows = recipes.map(function (recipe) {
                        var source = recipe.source, lang = recipe.language, rest = __rest(recipe, ["source", "language"]);
                        var recipeId = "cache_".concat(Date.now(), "_").concat(Math.random().toString(36).slice(2, 8));
                        var recipeData = __assign(__assign({}, rest), { id: recipeId });
                        var ingredientNames = (recipeData.ingredients || [])
                            .map(function (i) { return typeof i === 'string' ? i.toLowerCase().trim() : (i.name || '').toLowerCase().trim(); })
                            .filter(Boolean);
                        return {
                            recipe_id: recipeId,
                            recipe_data: recipeData,
                            required_ingredients: ingredientNames,
                        };
                    });
                    console.log('[CACHE-SAVE] Inserting', rows.length, 'to', table, ':', rows.map(function (r) { return r.recipe_data.title; }));
                    console.log('[CACHE-SAVE] Sample required_ingredients:', (_c = rows[0]) === null || _c === void 0 ? void 0 : _c.required_ingredients);
                    return [4 /*yield*/, supabase_1.supabase
                            .from(table)
                            .insert(rows)
                            .select()];
                case 1:
                    _a = _d.sent(), data = _a.data, error = _a.error;
                    if (!error) return [3 /*break*/, 3];
                    console.error('[CACHE-SAVE] Insert failed:', error.message, '| code:', error.code);
                    minimalRows = rows.map(function (r) { return ({
                        recipe_id: r.recipe_id,
                        recipe_data: r.recipe_data,
                    }); });
                    console.log('[CACHE-SAVE] Retrying without required_ingredients column...');
                    return [4 /*yield*/, supabase_1.supabase
                            .from(table)
                            .insert(minimalRows)
                            .select()];
                case 2:
                    _b = _d.sent(), retryData = _b.data, retryError = _b.error;
                    if (retryError) {
                        console.error('[CACHE-SAVE] Retry failed:', retryError.message);
                    }
                    else {
                        console.log('[CACHE-SAVE] Retry OK:', retryData === null || retryData === void 0 ? void 0 : retryData.length, 'rows into', table);
                    }
                    return [3 /*break*/, 4];
                case 3:
                    console.log('[CACHE-SAVE] OK:', data === null || data === void 0 ? void 0 : data.length, 'rows into', table);
                    _d.label = 4;
                case 4: return [2 /*return*/];
            }
        });
    });
}
function getPopularRecipes(language_1) {
    return __awaiter(this, arguments, void 0, function (language, limit) {
        var table, data, _a;
        if (limit === void 0) { limit = 10; }
        return __generator(this, function (_b) {
            switch (_b.label) {
                case 0:
                    table = getCacheTable(language);
                    _b.label = 1;
                case 1:
                    _b.trys.push([1, 3, , 4]);
                    return [4 /*yield*/, supabase_1.supabase
                            .from(table)
                            .select('*')
                            .order('created_at', { ascending: false })
                            .limit(limit)];
                case 2:
                    data = (_b.sent()).data;
                    if (!data || data.length === 0)
                        return [2 /*return*/, []];
                    return [2 /*return*/, data.map(rowToRecipe)];
                case 3:
                    _a = _b.sent();
                    return [2 /*return*/, []];
                case 4: return [2 /*return*/];
            }
        });
    });
}
