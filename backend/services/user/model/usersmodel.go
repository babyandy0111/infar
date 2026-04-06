package model

import (
	"context"
	"fmt"
	"github.com/zeromicro/go-zero/core/logx"

	"github.com/zeromicro/go-zero/core/stores/cache"
	"github.com/zeromicro/go-zero/core/stores/sqlx"
)

var _ UsersModel = (*customUsersModel)(nil)

type (
	UsersModel interface {
		usersModel
		InsertWithId(ctx context.Context, data *Users) (int64, error)
	}

	customUsersModel struct {
		*defaultUsersModel
		conn sqlx.SqlConn
	}

	pgInsertResult struct {
		id int64
	}
)

func (p pgInsertResult) LastInsertId() (int64, error) { return p.id, nil }
func (p pgInsertResult) RowsAffected() (int64, error) { return 1, nil }

func NewUsersModel(conn sqlx.SqlConn, c cache.CacheConf, opts ...cache.Option) UsersModel {
	return &customUsersModel{
		defaultUsersModel: newUsersModel(conn, c, opts...),
		conn:              conn,
	}
}

func (m *customUsersModel) InsertWithId(ctx context.Context, data *Users) (int64, error) {
	var insertedId int64
	query := fmt.Sprintf("insert into %s (%s) values ($1, $2, $3, $4) returning id", m.table, usersRowsExpectAutoSet)
	err := m.conn.QueryRowCtx(ctx, &insertedId, query, data.Account, data.Provider, data.PasswordHash, data.IsActive)
	if err != nil {
		logx.Errorf("InsertWithId error: %v", err)
		return 0, err
	}
	logx.Infof("User inserted successfully. ID: %d", insertedId)

	publicUsersProviderAccountKey := fmt.Sprintf("%s%v:%v", cachePublicUsersProviderAccountPrefix, data.Provider, data.Account)
	_ = m.DelCacheCtx(ctx, publicUsersProviderAccountKey)
	return insertedId, nil
}
